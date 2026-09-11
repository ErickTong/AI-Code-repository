#!/bin/bash
#RNA-seq 流水线模板（HISAT2 + featureCounts + DESeq2 + 微信通知）
#用法：复制到项目目录，修改"项目配置区"，确保 01data/ 下有 fastq 与 sampleid.txt，
#      00sample_group.txt / 00contrast_group.txt 已生成，然后 nohup 后台运行。
#详细约束见 skill references/constraints.md

################ 项目配置区（每个项目必改） ################
PREFIX=mango                  # 合并矩阵前缀，必须恰好5字符！classfy_DEGs_file.py 按 20 字符偏移解析文件名（"mango.counts.matrix."=20）
R1=_1.fq.gz                   # fastq 后缀模式：常见 _1.fq.gz/_2.fq.gz 或 _R1.fq.gz/_R2.fq.gz，用 ls 01data/ 确认
R2=_2.fq.gz
REF_FA=''                     # 参考基因组 fasta 路径（支持 .fa 或 .fa.gz）
REF_ANN=''                    # 注释文件路径（支持 .gtf 直接用；.gff/.gff.gz 自动 gffread 转 GTF）
MAP_PAR=4                     # 比对阶段并行样本数（每样本 MAP_THREADS 线程 hisat2 + 4 线程 samtools sort）
MAP_THREADS=12
QUANT_PAR=8                   # 定量阶段并行样本数（每样本单线程 Rscript）
TRIM=false                    # true=先 trimmomatic 再用 clean reads 比对；false=直接用原始 reads 比对（需用户确认）

################ 服务器常量（本服务器固定路径） ################
CONDA_SH=/data/Erick_Tong/software/miniconda24/etc/profile.d/conda.sh
ENV_QC=rna-seq                # fastqc/multiqc/hisat2/samtools/gffread/trimmomatic
ENV_R=R4                      # Rsubread/DESeq2/edgeR/limma
RSCRIPTS=/data/Erick_Tong/02Data_analysis_project/04RNA-seq_analysis/00Rscript   # abundance_estimates_to_matrix.pl 依赖同目录 support_scripts/
TRINITY_DE=/data/changchuanjun/necessary_packages/trinity-2.11.0-h5ef6573_0/bin/run_DE_analysis.pl
CLASSFY=./classfy_DEGs_file.py # 从 skill assets/ 复制到项目目录
WX=/data/Erick_Tong/05Analysis_script/15remind/remind_xtuis.sh   # 微信推送：bash $WX "标题" "内容"
TAG=$(date +%y%m%d)           # 通知标题日期

################ 前置检查 ################
if [ ${#PREFIX} -ne 5 ]; then echo "ERROR: PREFIX 必须为5字符，当前 '${PREFIX}'(${#PREFIX})。classfy_DEGs_file.py 固定偏移依赖"; exit 1; fi
NSAMPLE=$(wc -l < 01data/sampleid.txt)

mkdir -p 00ref
ln -sf $REF_FA 00ref/ref.src.fa
ln -sf $REF_ANN 00ref/ref.src.ann
#fasta：gz 则解压（hisat2-build 需要解压后文件）
[ -f 00ref/ref.fa ] || { case "$REF_FA" in *.gz) gunzip -c 00ref/ref.src.fa > 00ref/ref.fa;; *) ln -sf $(realpath $REF_FA) 00ref/ref.fa;; esac; }
#注释：gtf 直接用；gff 需 gffread 转（此版本 gffread 不支持 gz 输入，先解压）
if [ ! -f 00ref/ref.gtf ]; then
  case "$REF_ANN" in
    *.gtf)    ln -sf $(realpath $REF_ANN) 00ref/ref.gtf;;
    *.gff.gz) gunzip -c 00ref/ref.src.ann > 00ref/ref.gff && gffread 00ref/ref.gff -T -o 00ref/ref.gtf;;
    *.gff)    ln -sf $(realpath $REF_ANN) 00ref/ref.gff && gffread 00ref/ref.gff -T -o 00ref/ref.gtf;;
    *)        echo "ERROR: 无法识别注释格式 $REF_ANN"; exit 1;;
  esac
fi

bash $WX "$TAG RNA-seq" "流水线启动: ${NSAMPLE}样本, 前缀${PREFIX}"

################ 阶段函数 ################
function Ifastqc {
mkdir -p 02fastq
for i in $(cat 01data/sampleid.txt); do
  fastqc 01data/${i}$R1 -o 02fastq -t 4
  fastqc 01data/${i}$R2 -o 02fastq -t 4
done
multiqc 02fastq/*zip -o 02fastq
}

function IItrim {
#可选：trimmomatic 过滤（TRIM=true 时比对用 clean reads）
mkdir -p 01data/clean
for i in $(cat 01data/sampleid.txt); do
  trimmomatic PE -threads 24 \
    ./01data/${i}$R1 ./01data/${i}$R2 \
    ./01data/clean/${i}_1_paired.fq.gz ./01data/clean/${i}_1_unpair.fq.gz \
    ./01data/clean/${i}_2_paired.fq.gz ./01data/clean/${i}_2_unpair.fq.gz \
    LEADING:3 TRAILING:3 SLIDINGWINDOW:4:20 MINLEN:50 TOPHRED33
  rm -f 01data/clean/${i}_1_unpair.fq.gz 01data/clean/${i}_2_unpair.fq.gz
done
}

function IIImapping {
#建索引（幂等）
if [ ! -f 00ref/ref.fa.1.ht2 ]; then
  (cd 00ref && hisat2-build ref.fa ref.fa)
fi
#比对（MAP_PAR 样本并行，断点续跑：bai 存在则跳过）
mkdir -p 03mapping
n=0
for i in $(cat 01data/sampleid.txt); do
  if [ -f 03mapping/${i}.sort.bam.bai ]; then continue; fi
  if [ "$TRIM" = true ]; then FQ1=./01data/clean/${i}_1_paired.fq.gz; FQ2=./01data/clean/${i}_2_paired.fq.gz; else FQ1=./01data/${i}$R1; FQ2=./01data/${i}$R2; fi
  (
    hisat2 --new-summary -p $MAP_THREADS -x 00ref/ref.fa \
           -1 $FQ1 -2 $FQ2 \
           -S /dev/stdout 2> 03mapping/${i}.hisat2.log | samtools sort -@ 4 -O bam -o 03mapping/${i}.sort.bam -
    samtools index 03mapping/${i}.sort.bam 03mapping/${i}.sort.bam.bai
  ) &
  n=$((n+1))
  if [ $((n % MAP_PAR)) -eq 0 ]; then wait; fi
done
wait
}

function IVquant {
#featureCounts 定量（R4 环境；QUANT_PAR 样本并行，断点续跑）
mkdir -p 04Quantification
n=0
for i in $(cat 01data/sampleid.txt); do
  if [ -f 04Quantification/${i}.count ]; then continue; fi
  ( Rscript $RSCRIPTS/run-featurecounts.R -b 03mapping/${i}.sort.bam -g 00ref/ref.gtf -o 04Quantification/${i} ) &
  n=$((n+1))
  if [ $((n % QUANT_PAR)) -eq 0 ]; then wait; fi
done
wait
#合并矩阵（列名=basename去.count=样本名，须与 00sample_group.txt 第二列一致）
ls 04Quantification/*.count > 04Quantification/genes.quant_files.txt
#注意：matrix 输出到当前目录(cwd)而非 --quant_files 所在目录，必须移入 04Quantification/
perl $RSCRIPTS/abundance_estimates_to_matrix.pl \
    --est_method featureCounts \
    --quant_files 04Quantification/genes.quant_files.txt \
    --out_prefix $PREFIX
mv $PREFIX.*.matrix 04Quantification/
}

function Vcontrasts {
#DESeq2 差异分析（R4 环境）+ 结果分类
mkdir -p 05contrasts
perl $TRINITY_DE \
    --matrix 04Quantification/${PREFIX}.counts.matrix \
    --method DESeq2 \
    --samples_file 00sample_group.txt \
    --contrasts 00contrast_group.txt
mv ./*.dir/* 05contrasts
rm -f ./05contrasts/*.count_matrix ./05contrasts/*Rscript
python $CLASSFY
rm -r DESeq2.*
}

################ 主流程 ################
source $CONDA_SH
conda activate $ENV_QC

Ifastqc
[ "$TRIM" = true ] && IItrim
IIImapping
bash $WX "$TAG RNA-seq 进度" "比对完成: $(ls 03mapping/*.sort.bam.bai 2>/dev/null | wc -l)/${NSAMPLE} 样本"

conda activate $ENV_R
IVquant
bash $WX "$TAG RNA-seq 进度" "定量完成: $(ls 04Quantification/*.count 2>/dev/null | wc -l)/${NSAMPLE} 样本"

Vcontrasts
bash $WX "$TAG RNA-seq 完成" "全部流程结束, 差异结果在 05contrasts/, 共$(find 05contrasts -name 'DESeq2.DE_results' 2>/dev/null | wc -l)组对比"

# 流水线非显而易见约束（踩坑记录）

## 1. out_prefix 必须恰好 5 字符（最关键约束）

`classfy_DEGs_file.py`（assets/ 有副本）用**硬编码偏移**解析 Trinity 输出文件名：
- DE 结果：`filename[20:-18]`
- pdf 图：`filename[20:-35]`

`abundance_estimates_to_matrix.pl --out_prefix X` 生成 `X.counts.matrix.A_vs_B.DESeq2.DE_results`，
前 20 字符 = `{prefix}.counts.matrix.`，因此 **prefix 长度必须为 5**（如 mango/apple/grape/peach）。
否则分类目录名错位、pdf 与 DE_results 配对失败。

验证方法：
```bash
python3 -c "s='${PREFIX}.counts.matrix.A_vs_B.DESeq2.DE_results'; print(repr(s[20:-18]))"  # 应输出 'A_vs_B'
```

## 2. gffread 不支持 gz 输入

conda rna-seq 环境的 gffread 0.12.7 直接读 `.gff.gz` 会崩溃（stack smashing detected）。
必须先 `gunzip -c xx.gff.gz > xx.gff` 再 `gffread xx.gff -T -o xx.gtf`。

## 3. Trinity samples_file / contrasts 格式

`run_DE_analysis.pl --samples_file`（用空白符分隔，tab 安全）：
- 第 1 列 = 组名，第 2 列 = 样本名（`parse_sample_info` 取 `($sample_name, $replicate_name)`）
- `--contrasts` 文件：每行 `组A\t组B`，输出文件名为 `matrix前缀.A_vs_B.DESeq2.DE_results`（foldchange 方向为 log2(A/B)）

## 4. 矩阵列名 = 样本名

`abundance_estimates_to_matrix.pl` 用 `basename($file)` 去掉 `.count` 作为列名。
因此 `00sample_group.txt` 第 2 列样本名必须与 `04Quantification/{样本名}.count` 完全一致（含大小写、`#`、`-` 等特殊字符）。

## 5. 环境分工（本服务器）

| conda 环境 | 工具 | 阶段 |
|---|---|---|
| rna-seq | fastqc, multiqc, trimmomatic, hisat2, samtools, gffread | QC/比对 |
| R4 | Rsubread(featureCounts), DESeq2, edgeR, limma, argparser | 定量/差异 |

R4 需同时有 python3（classfy 脚本用）；perl 用系统 conda base 的即可。

## 6. 服务器路径常量

- `00Rscript/`（共享）：run-featurecounts.R、abundance_estimates_to_matrix.pl（**依赖同目录 support_scripts/**，不能单独拷走用）
- Trinity run_DE_analysis.pl：`/data/changchuanjun/necessary_packages/trinity-2.11.0-h5ef6573_0/bin/`
- 微信推送：`/data/Erick_Tong/05Analysis_script/15remind/remind_xtuis.sh`（旧路径 `05Analysis_script/remind.sh` 已失效，勿用）
- conda：`source /data/Erick_Tong/software/miniconda24/etc/profile.d/conda.sh`

## 7. 并行与资源

- 服务器 128 核，多用户共用（常驻他人 java 任务，负载 ~20 属正常）
- 比对：4 样本 × (12 hisat2 + 4 samtools) ≈ 64 核，已验证安全
- 定量：8 并行单线程，几乎瞬时
- 运行前检查：`nproc; uptime; free -g; df -h <目录>`；估算 fastq 总量 `du -sh 01data/`
- 预计耗时：48 样本约 8h（FastQC 1h + 建索引 20min + 比对 6h + 定量 30min + DESeq2 20min）

## 8. 断点续跑语义

- 比对：`03mapping/{样本}.sort.bam.bai` 存在则跳过
- 定量：`04Quantification/{样本}.count` 存在则跳过
- 中断后**直接重跑脚本即可**，无已完成样本重算
- 注意：bam 写到一半中断（无 bai）会重跑该样本，安全

## 9. 输入数据检测要点（迁移到新项目时）

- fastq 后缀模式：`ls 01data/ | head` 确认 `_1/_2` 还是 `_R1/_R2`（不同测序公司不同）
- 样本名特殊字符：`#`（苹果项目 MYB2-OE-1#）、大小写混合都可直接用，无需清洗
- 参考基因组格式四象限：fa/fa.gz × gtf/gff(.gz)，模板已自动处理
- GFF 来源（AUGUSTUS/GWH 等）经 gffread 转换后 gene_id 形如 `g1`、transcript_id `g1.t1`，featureCounts 直接兼容
- 基因组版本选择（如单倍型 all/hap1/hap2）：检测到多个版本时**必须问用户**，各版本基因集不同
- 二倍体植物用 all（含两套单倍型）会引入同源基因计数拆分，用户在芒果项目明确选了 all——沿用用户选择，不代做决定

## 10. 组间对比设计（必须问用户，不要默认）

常见方案（用 AskUserQuestion 给选项）：
- 各处理 vs 对照（如各温度 vs 0h）
- 同时间点处理间两两比较（HT vs LT vs MT）
- 两者都要
- 全部两两比较（样本组多时组合爆炸，n 组 = n(n-1)/2 对比）

DESeq2 无重复（每组 1 样本）会失败，检测分组时若发现重复数 <2 需提醒用户。

## 11. matrix 输出在 cwd，不在 --quant_files 目录（260909 踩坑）

`abundance_estimates_to_matrix.pl --out_prefix X` 把 `X.counts.matrix` / `X.TMM.EXPR.matrix` 生成在**当前工作目录**，与 --quant_files 路径无关。若 Vcontrasts 引用 `04Quantification/X.counts.matrix` 会因找不到文件 die（run_DE_analysis.pl line 337），且后续 mv/rm 级联失败、脚本仍发"全部完成"误报。
**模板已在合并矩阵后加 `mv $PREFIX.*.matrix 04Quantification/`，勿删。** trinity 此版本不支持 `--threads` 参数（报 don't understand options），差异对比只能串行，15 对比约 20-30 分钟。

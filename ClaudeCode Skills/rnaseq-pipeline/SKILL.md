---
name: rnaseq-pipeline
description: 实验室标准转录组 RNA-seq 分析流水线（FastQC → HISAT2 → featureCounts → DESeq2），含参数化脚本模板、微信进度通知、后台运行监控。当用户要求：运行/搭建/迁移 RNA-seq 转录组分析流程、做差异表达(DEG)分析、在新项目目录跑转录组流水线、修改转录组分析脚本的分组比较、监控转录组运行进度时使用。触发词包括：转录组、RNA-seq、差异表达、DESeq2、比对定量、表达谱。
---

# RNA-seq 流水线（实验室标准流程）

把本项目（模板）迁移到新的测序数据和参考基因组：检测输入 → 询问关键决策 → 生成文件 → 后台运行 → 微信监控。

**必读**：动手前先读 [references/constraints.md](references/constraints.md)（10 条踩坑约束，尤其 out_prefix 必须 5 字符）；运行监控阶段读 [references/monitoring.md](references/monitoring.md)。

## Step 1: 检测输入数据（先检测再询问，不问能自己查到的）

```bash
# fastq 命名模式（_1/_2 还是 _R1/_R2）、样本数、样本命名规律
ls 01data/ | head -20; ls 01data/ | wc -l
# 参考基因组文件格式（fa/fa.gz × gtf/gff/gff.gz；有多个版本如 all/hap1/hap2 都列出）
ls -lh <参考基因组目录>
# 基因组规模（供并行度和内存判断）
zcat <gff> | awk -F'\t' '$3=="gene"' | wc -l
# 服务器资源与磁盘
nproc; uptime; free -g; df -h <项目目录>; du -sh 01data/
```

从样本名推断分组结构（如 `6h-HT-1` → 时间×处理×重复），统计每组重复数。

## Step 2: 询问用户（用 AskUserQuestion 一次性问完）

必问（答案决定脚本参数）：
1. **对比设计**：基于 Step1 检测到的分组给选项（各处理 vs 对照 / 同时间点两两 / 两者都要）
2. **比对用原始还是 clean reads**（trimmomatic 是否启用）
3. **参考基因组版本**：检测到多个版本（all/hap1/hap2）时问用哪个；单一则跳过
4. **5 字符前缀**（如 mango/apple）：用于所有输出文件命名，**长度必须恰好 5**（classfy 脚本硬编码偏移），在选项中明确说明该约束

重复数 <2 的组要提醒（DESeq2 无重复会失败）。

## Step 3: 生成项目文件

1. `01data/sampleid.txt`：`ls 01data/*_1.fq.gz | sed 's|.*/||; s|_1\.fq\.gz$||' | sort >`
   （后缀按实际检测调整）
2. `00sample_group.txt`：组名\t样本名（Trinity 格式，列名须与 matrix 列名逐字符一致）
3. `00contrast_group.txt`：每行 `组A\t组B`（输出为 A_vs_B，log2FC 方向 = A/B）
4. 复制 `assets/pipeline_template.sh` → 项目 `00rnaseq_<项目标识>.sh`，填配置区：
   PREFIX / R1,R2 / REF_FA / REF_ANN / 并行度（参考 constraints.md §7：比对 4×12、定量 8）
5. 复制 `assets/classfy_DEGs_file.py` 到项目目录（模板按 `./classfy_DEGs_file.py` 引用）
6. run-featurecounts.R 用共享目录 00Rscript 的；若该目录不可用则从 assets/ 复制并把模板中 RSCRIPTS 改为 `./`

## Step 4: 校验（运行前必须全过）

```bash
# 样本↔fastq 一一对应
while read s; do [ -f "01data/${s}_1.fq.gz" ] || echo "缺 $s"; done < 01data/sampleid.txt
# 分组↔样本名一致
diff <(cut -f2 00sample_group.txt | sort) <(sort 01data/sampleid.txt)
# 对比组名都存在于分组
comm -23 <(cut -f1,2 00contrast_group.txt | tr '\t' '\n' | sort -u) <(cut -f1 00sample_group.txt | sort -u)
# 前缀偏移自检（模板运行时也会检查）
bash -n <脚本>; python3 -c "s='${P}.counts.matrix.A_vs_B.DESeq2.DE_results'; assert s[20:-18]=='A_vs_B'"
```
参考基因组若是 gff.gz，可先手动执行 gffread 转换验证（先解压！gffread 不读 gz）。

## Step 5: 启动（详见 references/monitoring.md §1）

先发微信测试消息确认通道，再 nohup 后台启动 + 记录 PID + sleep 15 查日志确认开跑。

## Step 6: 监控

按 references/monitoring.md §2 用 CronCreate 设约 30 分钟周期的监控（进度摘要/完成/异常中断三类通知），并向用户说明会话级限制。

## 中断恢复

流水线支持断点续跑（bai/count 存在即跳过），中断后直接重新运行脚本，不要手动清理中间文件。

## 完成后

按 references/monitoring.md §4 检查比对率（>80% 为佳）、矩阵行数、对比数，向用户汇报结果位置（`05contrasts/{对比名}/`）与后续可选分析（veen/WGCNA 提取脚本模式见 constraints.md 及模板原项目尾部注释）。

# 运行监控与微信通知流程

## 0. 微信通道

脚本：`/data/Erick_Tong/05Analysis_script/15remind/remind_xtuis.sh`（xtuis 服务）
```bash
bash /data/Erick_Tong/05Analysis_script/15remind/remind_xtuis.sh "标题" "详细内容(markdown)"
```
返回 `{"code":200,"message":"Message Queue Success"}` 即成功。
**启动流水线前先发一条测试消息**确认通道可用。

## 1. 启动方式

```bash
mkdir -p logs
nohup bash <流水线脚本> > logs/run_$(date +%y%m%d).log 2>&1 &
pgrep -f "bash <脚本名>" > logs/pipeline.pid   # 记录主进程 PID
```
- 流水线内置节点通知（脚本自身发）：启动 / 比对完成 / 定量完成 / 全部完成，各含计数
- 首次启动后 `sleep 15` 查看日志开头，确认 FastQC 正常开跑再离开

## 2. 定时监控（CronCreate，会话级）

流水线启动后立即用 CronCreate 设置（约每 30 分钟，避开整点分钟，如 `11,41 * * * *`），
prompt 要点（按项目实际替换目录、脚本名、样本数、目标对比数）：

```
检查 RNA-seq 流水线进度并发送微信通知（只读检查，不要启动或干预流水线）。
项目目录：<项目路径>

执行：
1. 进程存活: pgrep -f "bash <脚本名>"
2. 阶段计数:
   - FastQC: ls 02fastq/*.zip 2>/dev/null | wc -l（目标 2×N 样本）
   - 比对: ls 03mapping/*.sort.bam.bai 2>/dev/null | wc -l（目标 N）
   - 定量: ls 04Quantification/*.count 2>/dev/null | wc -l（目标 N）
   - 差异: find 05contrasts -name "DESeq2.DE_results" 2>/dev/null | wc -l（目标对比数）
3. 日志尾部: tail -20 logs/<日志名>.log 查 Error/Fatal/Cannot

发送: bash /data/Erick_Tong/05Analysis_script/15remind/remind_xtuis.sh "<项目> RNA-seq 进度" "<摘要>"

判断：
- 进程存活 → 发进度摘要（当前阶段+计数+按完成速率估剩余时间）
- 进程消失且差异结果达标 → 发"全部完成"，CronDelete 本监控，向用户报告
- 进程消失但未完成 → 发"异常中断"（附日志错误），CronDelete 本监控，报告用户需检查日志
- 日志有 Error 但进程在 → 通知附错误摘要，继续监控
```

## 3. 会话级限制（务必告知用户）

- nohup 流水线独立于会话，退出 Claude Code 不影响运行，内置节点通知照发
- **CronCreate 监控是会话级的**，退出会话即失效；如需长期监控提醒用户保持会话，或仅依赖脚本内置节点通知

## 4. 完成后检查清单

```bash
# 比对率抽查（应 >80%，植物转录组常见 70-90%）
grep "overall alignment rate" 03mapping/*.hisat2.log | head
# 定量完整性
wc -l 04Quantification/mango.counts.matrix      # 行数≈基因数+表头
# 差异结果完整
find 05contrasts -name "DESeq2.DE_results" | wc -l   # = 对比数
```
结果解读：`05contrasts/{对比名}/` 子目录内 DE_results + pdf；后续 veen/WGCNA 提取脚本见
原项目脚本尾部注释块（标注 up/down 的 awk，列位置 $7=log2FC $10=pvalue $11=padj）。

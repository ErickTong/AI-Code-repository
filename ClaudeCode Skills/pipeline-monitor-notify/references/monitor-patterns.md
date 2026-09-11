# scan_progress() 定制模式速查

定制 `scripts/monitor_template.sh` 的【HOOK 区】时，从以下六种模式选择并粘贴改写。
所有模式都必须写入四个全局变量：`n_done`、`done_list`（空格分隔，条目名勿含空格）、
`running_item`、`STUCK_METRIC`。可选写 `stage`（启用阶段切换通知）。

选择原则：
- 有"每个样本/任务对应固定输出文件" → 模式 1 或 2
- 进度只体现在日志里 → 模式 3
- 没有进度概念，只关心跑没跑完 → 模式 4（TOTAL 留 0）
- Slurm 作业 → 模式 5
- 多阶段串联流程 → 模式 6

---

## 模式 1：按样本文件完整性（最常用、最可靠）

适用：多样本流程，每样本需多个输出文件齐全才算完成（如 partition: A/B/D × 1/2 共 6 个 fq）。
要点：加上"中间文件已清理"条件可避免把写入中的文件误判为完成。

```bash
ID=/path/to/sampleid.txt      # 样本表, 每行一个样本名
OUTDIR=/path/to/01partition   # 输出目录
FILES_PER_ITEM="A_1 A_2 B_1 B_2 D_1 D_2"   # 每样本的文件后缀(相对样本名)

scan_progress() {
    n_done=0; done_list=""; running_item=""; STUCK_METRIC=""
    local s suf ok total_bytes=0
    for s in $(cat "$ID"); do
        ok=1
        for suf in $FILES_PER_ITEM; do
            [ -s "$OUTDIR/${s}.${suf}.fq.gz" ] || { ok=0; break; }
        done
        # 中间文件已清理(脚本的收尾动作)才确认完成, 防止写入中被误判
        if (( ok )) && [ ! -e "$OUTDIR/${s}.out.paf" ]; then
            n_done=$((n_done+1)); done_list="$done_list $s"
        elif [ -e "$OUTDIR/${s}.out.paf" ]; then
            running_item=$s
        fi
    done
    # 字节数作卡死指标(du 较慢可改用 ls|wc -l)
    STUCK_METRIC=$(du -sb "$OUTDIR" 2>/dev/null | cut -f1)
}
```

## 模式 2：按输出文件计数

适用：每个样本/任务对应一个输出文件（如每样本一个 VCF/BAM）。

```bash
GLOB='/path/to/variants/*.vcf.gz'   # 引号包裹防提前展开
SUFFIX='.vcf.gz'
TOTAL=21   # 样本表行数: TOTAL=$(grep -c . /path/to/sampleid.txt)

scan_progress() {
    n_done=0; done_list=""; running_item=""; STUCK_METRIC=""
    local f
    for f in $GLOB; do
        [ -e "$f" ] || continue
        n_done=$((n_done+1)); done_list="$done_list $(basename "$f" "$SUFFIX")"
    done
    STUCK_METRIC=$n_done
}
```
注：无法给出 running_item 时留空即可。

## 模式 3：按日志关键字

适用：Snakemake/Nextflow/自定义流程日志中有明确的完成标记。

```bash
FLOW_LOG=/path/to/flow.log
DONE_RE='^Finished sample '        # 每条完成记录的正则(按实际日志改)
TOTAL=21

scan_progress() {
    n_done=0; done_list=""; running_item=""; STUCK_METRIC=""
    local line
    while IFS= read -r line; do
        n_done=$((n_done+1)); done_list="$done_list $line"
    done < <(grep -E "$DONE_RE" "$FLOW_LOG" 2>/dev/null | sed 's/.*sample //' | sort -u)
    running_item=$(grep -E 'Processing sample |Running sample ' "$FLOW_LOG" 2>/dev/null | tail -1 | sed 's/.*sample //')
    STUCK_METRIC=$(stat -c %s "$FLOW_LOG" 2>/dev/null)   # 日志大小持续不变 => 卡死
}
```
注：大日志 grep 开销可接受（每 INTERVAL 一次）；Nextflow 可用 `.nextflow.log` 中 `Submitted`/`Completed` 统计。

## 模式 4：纯进程监控（无进度概念）

适用：单个长任务，没有可统计的中间产物；TOTAL 保持 0（is_all_done 默认恒真，进程消失即正常结束）。

```bash
scan_progress() {
    n_done=0; done_list=""; running_item=""; STUCK_METRIC=""
    # 无进度可统计, 全部留空; 若有输出文件持续增长, 可用作卡死指标:
    # STUCK_METRIC=$(stat -c %s /path/to/output.bam 2>/dev/null)
}
```

## 模式 5：Slurm 作业

适用：批处理作业投递到 Slurm 队列。PROC_PATTERN 不能用 pgrep（作业不在本机进程表），
需将主循环的 `count_alive()` 一并覆写为 squeue 检查。

```bash
JOBID=123456
# 覆写骨架的 count_alive():
count_alive() {
    squeue -h -j "$JOBID" 2>/dev/null | wc -l   # 0=作业已结束
}

scan_progress() {
    n_done=0; done_list=""; running_item=""; STUCK_METRIC=""
    # 数组作业进度: 已完成分任务数
    local st cnt=0
    while IFS= read -r st; do
        [[ $st == COMPLETED* ]] && cnt=$((cnt+1))
    done < <(sacct -j "$JOBID" -X -n -o State 2>/dev/null)
    n_done=$cnt
    STUCK_METRIC=$cnt
}
# TOTAL=数组任务数; sacct 不可用时退化为模式 1/2 统计输出文件
```

## 模式 6：多阶段串联

适用：partition → clean → mapping 等多阶段流水线。骨架的 stage 变量在变化时自动发
"进入XX阶段"通知；进度口径随阶段切换。

```bash
ID=/path/to/sampleid.txt
scan_progress() {
    n_done=0; done_list=""; running_item=""; stage=""; STUCK_METRIC=""
    local s h ok

    # 阶段1: partition (按模式1统计)
    local p_done=0
    for s in $(cat "$ID"); do
        ok=1
        for h in A B D; do
            [ -s "/path/01partition/${s}.${h}_1.fq.gz" ] && [ -s "/path/01partition/${s}.${h}_2.fq.gz" ] || { ok=0; break; }
        done
        (( ok )) && { p_done=$((p_done+1)); done_list="$done_list $s"; }
    done

    if (( p_done < $(grep -c . "$ID") )); then
        stage="partition"; n_done=$p_done
    else
        # 阶段2: clean (目录不同, 同样统计)
        stage="clean"; n_done=0; done_list=""
        for s in $(cat "$ID"); do
            ok=1
            for h in A B D; do
                [ -s "/path/02clean/${s}.${h}_1.fq.gz" ] && [ -s "/path/02clean/${s}.${h}_2.fq.gz" ] || { ok=0; break; }
            done
            (( ok )) && { n_done=$((n_done+1)); done_list="$done_list $s"; }
        done
    fi
    STUCK_METRIC=$(du -sb /path/02clean 2>/dev/null | cut -f1)
}
```
注：is_all_done 默认 `n_done >= TOTAL` 只看最终阶段，阶段一完成数不影响判定。
建议 TOTAL=样本数。

---

## 定制检查清单

1. `bash -n monitor_xxx.sh` 语法通过
2. 临时把 `INTERVAL=5 DRY_RUN=1`，前台跑一轮，确认 LOG 中进度数字与实际相符（与 `ls` 人工核对）
3. done_list 条目名与上轮 diff 正常（通知不重发）
4. STUCK_METRIC 在流程正常推进时会变化（否则卡死预警误报）；流程空闲等待时段会误报的场景，将 STUCK_METRIC 置空串禁用卡死预警
5. 测试通过后改回 `INTERVAL=300 DRY_RUN=0`，nohup 正式部署

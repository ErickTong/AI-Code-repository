#!/usr/bin/env bash
# =====================================================================
# pipeline-monitor-notify: 周期监控骨架模板
# 用途: 生信流程后台监控, 微信推送 条目进度/阶段切换/全部完成/异常中断/卡死预警
#
# 使用: 复制本模板到项目 run_logs/ 目录(勿直接改 skill 目录内模板),
#       定制【配置区】和【HOOK 区】后 nohup 启动:
#         nohup bash monitor_xxx.sh > /dev/null 2>&1 &
# 定制参考: skill pipeline-monitor-notify 的 references/monitor-patterns.md
# =====================================================================

# =====================【配置区】按流程替换 =====================
TITLE_PREFIX="[项目名]"                       # 通知标题前缀, 如 "260907"
PROC_PATTERN="my_pipeline_script|minimap2|fastp"  # 主流程进程 pgrep -f 模式(ERE), 仅用于存活判定
INTERVAL=300                                  # 轮询间隔(秒)
DRY_RUN=0                                     # 1=只写日志不真实发微信(冒烟测试)
TOTAL=0                                       # 总条目数(样本/任务数); 0=纯进程监控
STUCK_THRESHOLD=12                            # 连续N轮 STUCK_METRIC 无变化且进程在 => 卡死预警
LOG="/path/to/run_logs/monitor_xxx.log"       # 监控日志路径(必填)
FLOW_LOG="/path/to/run_logs/flow_output.log"  # 流程自身日志(异常通知时提示查看, 可空)
NEXT_STEP_HINT=""                             # 全部完成后的下一步提示(可空)
REMIND="bash /data/Erick_Tong/05Analysis_script/15remind/remind_xtuis.sh"

# =====================【HOOK 区】按流程定制 ======================
# scan_progress(): 唯一必须定制的函数, 每轮调用一次。
# 需写入全局变量:
#   n_done        已完成条目数
#   done_list     已完成条目名, 空格分隔(用于增量通知, 条目名中勿含空格)
#   running_item  当前正在处理的条目名(可空)
#   STUCK_METRIC  卡死检测指标(输出文件数/总字节数等活跃指标, 可空串禁用)
# 可选写入:
#   stage         当前阶段名(非空时启用阶段切换通知)
scan_progress() {
    n_done=0; done_list=""; running_item=""; STUCK_METRIC=""
    # TODO: 按 references/monitor-patterns.md 选择模式实现, 示例(按输出文件计数):
    # local f
    # for f in /path/to/outdir/*.vcf.gz; do [ -e "$f" ] || continue; n_done=$((n_done+1)); done_list="$done_list $(basename $f .vcf.gz)"; done
    # STUCK_METRIC=$(du -sb /path/to/outdir 2>/dev/null | cut -f1)
    :
}

# is_all_done(): 全部完成判定。默认: TOTAL>0 时 n_done>=TOTAL; TOTAL=0(纯进程)时恒真。
is_all_done() {
    if (( TOTAL > 0 )); then (( n_done >= TOTAL )); else return 0; fi
}

# ===================== 固定骨架(勿改) ============================
set -u

# --- 单实例保护: 已有存活实例则拒绝启动 ---
PIDFILE="${LOG}.pid"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
    echo "[$(date '+%F %T')] 已有监控实例运行(PID $(cat "$PIDFILE")), 请先 kill 再启动" | tee -a "$LOG" >&2
    exit 1
fi
mkdir -p "$(dirname "$LOG")"
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

# --- 微信发送: DRY_RUN 只记日志; 发送结果记入 LOG ---
send_notify() {
    local title=$1 desp=${2:-}
    if (( DRY_RUN )); then
        echo "[$(date '+%F %T')] [DRY] 微信: $title | $desp" >> "$LOG"
        return 0
    fi
    local resp
    resp=$($REMIND "$title" "$desp" 2>&1)
    echo "[$(date '+%F %T')] 微信已发: $title | $desp | resp:${resp:0:80}" >> "$LOG"
}

# --- 本脚本及全部祖先进程PID(祖先bash的命令行可能含模式串, 如 Claude/CI 的包装shell) ---
ancestor_pids() {
    local p=$$
    while [ -n "$p" ] && [ "$p" != "0" ]; do
        echo "$p"
        p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
    done
}

# --- 主流程存活进程数 ---
# 排除两类干扰: 1) 监控自身及全部祖先(前台运行时, 用户/Claude包装shell的命令行含模式串)
#              2) 命令行含本脚本名的进程(其他监控实例/包装兄弟进程; 真实流程进程不可能叫本脚本名)
count_alive() {
    local excl self
    excl=$(ancestor_pids | paste -sd'|' -)
    self=$(pgrep -f -- "$(basename "$0")" | paste -sd'|' -)
    pgrep -f "$PROC_PATTERN" | grep -vwE "$excl" | grep -vwE "${self:-__none__}" | wc -l
}

# --- 初始化状态 ---
prev_done=""; prev_stage=""; pending_items=""
ever_seen=0; last_item_ts=0
stuck_count=0; last_metric="__init__"

scan_progress
echo "[$(date '+%F %T')] 监控启动 (间隔${INTERVAL}s, DRY_RUN=$DRY_RUN): 进度 $n_done/$TOTAL (进行中:${running_item:-无})${stage:+ [阶段:$stage]}" >> "$LOG"
send_notify "$TITLE_PREFIX 监控启动" "进度 $n_done/$TOTAL (${running_item:-无进行中})"

while true; do
    sleep "$INTERVAL"
    scan_progress
    n_alive=$(count_alive)
    (( n_alive > 0 )) && ever_seen=1

    echo "[$(date '+%F %T')] 进程:$n_alive | 进度:$n_done/$TOTAL (进行中:${running_item:-无})${stage:+ [阶段:$stage]}${pending_items:+ [待通知:$pending_items]}" >> "$LOG"

    # --- 阶段切换通知 ---
    if [ -n "${stage:-}" ] && [ "$stage" != "$prev_stage" ]; then
        send_notify "$TITLE_PREFIX 进入${stage}阶段" "进度 $n_done/$TOTAL"
        prev_stage="$stage"
    fi

    # --- 条目完成增量通知(打包, 防重发) ---
    new_items=""
    for it in $done_list; do
        case " $prev_done " in *" $it "*) ;; *) new_items="$new_items $it";; esac
    done
    prev_done="$done_list"
    pending_items="$pending_items$new_items"
    if [ -n "${pending_items// /}" ]; then
        npend=$(echo $pending_items | wc -w)
        if (( TOTAL > 20 )); then need=5; else need=1; fi
        now=$(date +%s)
        if (( npend >= need )) || is_all_done || (( n_alive == 0 )); then
            if (( now - last_item_ts >= 60 )); then
                send_notify "$TITLE_PREFIX 进度" "完成:$pending_items ($n_done/$TOTAL)"
                pending_items=""; last_item_ts=$now
            fi
        fi
    fi

    # --- 卡死预警(连续 STUCK_THRESHOLD 轮指标无变化且进程仍在, 触发一次) ---
    if [ -n "$STUCK_METRIC" ]; then
        if [ "$STUCK_METRIC" = "$last_metric" ]; then
            stuck_count=$((stuck_count + 1))
        else
            stuck_count=0; last_metric="$STUCK_METRIC"
        fi
        if (( n_alive > 0 && stuck_count == STUCK_THRESHOLD )); then
            send_notify "$TITLE_PREFIX 卡死预警" "连续约$(( STUCK_THRESHOLD * INTERVAL / 60 ))分钟进度指标无变化, 进度 $n_done/$TOTAL, 请检查"
        fi
    fi

    # --- 完成/中断判定(须先见过流程进程, 避免流程晚启动误报) ---
    if (( n_alive == 0 && ever_seen == 1 )); then
        if [ -n "${pending_items// /}" ]; then
            send_notify "$TITLE_PREFIX 进度" "完成:$pending_items ($n_done/$TOTAL)"
            pending_items=""
        fi
        if is_all_done; then
            send_notify "$TITLE_PREFIX 全部完成" "进度 $n_done/$TOTAL${NEXT_STEP_HINT:+, $NEXT_STEP_HINT}"
            echo "[$(date '+%F %T')] 正常完成，监控退出" >> "$LOG"
        else
            send_notify "$TITLE_PREFIX 异常中断" "进度 $n_done/$TOTAL, 流程进程消失, 请检查 ${FLOW_LOG:-流程日志}"
            echo "[$(date '+%F %T')] 异常中断，监控退出" >> "$LOG"
        fi
        exit 0
    fi

    # --- 流程从未出现, 宽限提醒(只提醒一次) ---
    if (( n_alive == 0 && ever_seen == 0 )); then
        if [ -z "${wait_warned:-}" ]; then
            echo "[$(date '+%F %T')] 尚未检测到流程进程($PROC_PATTERN), 继续等待..." >> "$LOG"
            wait_warned=1
        fi
    fi
done

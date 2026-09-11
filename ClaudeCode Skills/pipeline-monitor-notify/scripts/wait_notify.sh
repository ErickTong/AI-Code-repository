#!/usr/bin/env bash
# =====================================================================
# pipeline-monitor-notify: 简单等待模式
# 用途: 等待指定进程/任务结束, 微信推送 成功/失败/超时 通知(单任务场景)
#
# 用法: wait_notify.sh <进程匹配模式> [选项]
#   <进程匹配模式>   pgrep -f 的 ERE 模式, 用于识别目标进程
#   -t TEXT          成功通知标题 (默认: 任务完成)
#   -f TEXT          失败通知标题 (默认: 任务异常退出)
#   -d TEXT          通知详情 (默认: 目标进程已结束)
#   -s CMD           成功判定命令: 进程消失后执行, 退出码0=成功, 非0=失败
#                    (默认: 不判定, 进程消失即视为成功)
#   -T SEC           超时秒数, 超时且进程仍在则发超时通知后退出 (默认0=不限)
#   -i SEC           检查间隔 (默认: 60)
#   --dry-run        只打印不真实发送微信(测试用)
#
# 示例:
#   nohup bash wait_notify.sh "bwa-mem2 mem" -t "比对完成" -f "比对失败" \
#       > ~/run_logs/wait_bwa.log 2>&1 &
#   bash wait_notify.sh "sleep 30" -i 5 -s "test -s /path/result.bam" --dry-run
# =====================================================================

PATTERN=""; TITLE_OK="任务完成"; TITLE_FAIL="任务异常退出"
DESP="目标进程已结束"; SUCCESS_CMD=""; TIMEOUT=0; INTERVAL=60; DRY_RUN=0

if [ $# -lt 1 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    sed -n '2,22p' "$0"; exit 0
fi
PATTERN=$1; shift
while [ $# -gt 0 ]; do
    case $1 in
        -t) TITLE_OK=$2; shift 2;;
        -f) TITLE_FAIL=$2; shift 2;;
        -d) DESP=$2; shift 2;;
        -s) SUCCESS_CMD=$2; shift 2;;
        -T) TIMEOUT=$2; shift 2;;
        -i) INTERVAL=$2; shift 2;;
        --dry-run) DRY_RUN=1; shift;;
        *) echo "未知选项: $1" >&2; exit 1;;
    esac
done

notify() {
    local title=$1 desp=${2:-}
    if (( DRY_RUN )); then
        echo "[$(date '+%F %T')] [DRY] 微信: $title | $desp"
        return 0
    fi
    local resp
    resp=$(bash /data/Erick_Tong/05Analysis_script/15remind/remind_xtuis.sh "$title" "$desp" 2>&1)
    echo "[$(date '+%F %T')] 微信已发: $title | $desp | resp:${resp:0:80}"
}

# 本脚本及全部祖先进程的PID列表(祖先bash的命令行可能含模式串, 如 Claude/CI 的包装shell)
ancestor_pids() {
    local p=$$
    while [ -n "$p" ] && [ "$p" != "0" ]; do
        echo "$p"
        p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
    done
}

# 目标进程存活数
# 排除两类干扰: 1) 自身及全部祖先(前台运行时, 用户/Claude包装shell的命令行含模式串)
#              2) 命令行含本脚本名的进程(其他监控实例/包装兄弟进程; 真实任务进程不可能叫本脚本名)
count_alive() {
    local excl self
    excl=$(ancestor_pids | paste -sd'|' -)
    self=$(pgrep -f -- "$(basename "$0")" | paste -sd'|' -)
    pgrep -f "$PATTERN" | grep -vwE "$excl" | grep -vwE "${self:-__none__}" | wc -l
}

echo "[$(date '+%F %T')] 开始监控: 模式='$PATTERN' 间隔=${INTERVAL}s 超时=${TIMEOUT}s DRY_RUN=$DRY_RUN"

# 启动前置检查: 目标进程必须已存在, 否则退出(防止任务尚未启动时误发完成通知)
n0=$(count_alive)
if (( n0 == 0 )); then
    echo "[$(date '+%F %T')] 错误: 未检测到目标进程('$PATTERN'), 请先启动任务再部署监控" >&2
    notify "监控部署失败" "wait_notify 未检测到目标进程: $PATTERN"
    exit 1
fi

start_ts=$(date +%s)
while true; do
    sleep "$INTERVAL"
    n=$(count_alive)

    if (( n > 0 )); then
        echo "[$(date '+%F %T')] 目标进程运行中($n个)"
        if (( TIMEOUT > 0 )); then
            now=$(date +%s)
            if (( now - start_ts >= TIMEOUT )); then
                notify "任务超时" "已等待$(( (now - start_ts) / 60 ))分钟, 进程仍在运行: $PATTERN"
                exit 0
            fi
        fi
        continue
    fi

    # 进程消失 => 判定成功/失败
    if [ -n "$SUCCESS_CMD" ]; then
        if bash -c "$SUCCESS_CMD" >/dev/null 2>&1; then
            notify "$TITLE_OK" "$DESP (成功判定通过: $SUCCESS_CMD)"
        else
            notify "$TITLE_FAIL" "$DESP (成功判定未通过: $SUCCESS_CMD)"
        fi
    else
        notify "$TITLE_OK" "$DESP"
    fi
    echo "[$(date '+%F %T')] 监控结束"
    exit 0
done

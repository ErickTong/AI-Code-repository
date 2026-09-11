---
name: pipeline-monitor-notify
description: 为生信分析流程生成后台监控方案，通过微信推送逐样本进度通知、完成提醒和异常/卡死告警。当用户要求"监控流程/任务并微信通知我"、"跑完提醒我"、"出错发微信"、"后台监控+推送进度"、"部署监控脚本"等需要主动推送到微信的场景时使用。注意：若用户只是想查看当前任务运行状态（被动查询），应使用 task-monitor skill；本 skill 专门处理需要主动微信推送的场景。
---

# pipeline-monitor-notify：生信流程监控 + 微信提醒

为长周期生信分析流程部署后台监控，进度/完成/异常自动推送到微信。

**与 task-monitor 的边界**：用户说"看看现在跑的怎么样/检查下进度" → 用 task-monitor（被动查询）；用户说"跑完提醒我/出错微信通知我/帮我监控这个流程" → 用本 skill（主动推送）。

**微信渠道**（统一使用，旧版 remind.sh 已废弃）：
```bash
bash /data/Erick_Tong/05Analysis_script/15remind/remind_xtuis.sh "标题" "详情(可选)"
```

## 两种模式

| 场景 | 模式 | 工具 |
|---|---|---|
| 单任务，跑完/失败发一条微信即可 | 简单等待 | `scripts/wait_notify.sh`（参数化，直接调用） |
| 多样本/多阶段长流程，需要逐样本进度、异常/卡死告警 | 周期监控 | `scripts/monitor_template.sh`（复制到项目后定制部署） |

## 工作流程

### 步骤 1：信息收集
从对话上下文推断，缺则询问用户：
- 主流程进程特征：脚本全名或唯一关键字（用于 pgrep 存活判定，避免过宽误匹配）
- 进度口径：总样本/任务数（TOTAL）、输出目录与文件命名规则、"单条目完成"的判定标志（如 6 个 fq 齐全且中间文件已清理）、样本表路径
- 流程自身日志路径（用于异常通知提示用户查看）
- 是否分阶段（如 partition → clean → mapping）
- 通知粒度偏好（每个样本都通知，还是每 N 个一批）

### 步骤 2：模式选择
单任务 → 步骤 2a；多样本/多阶段 → 步骤 2b。

### 步骤 2a：简单等待模式（wait_notify.sh）
```bash
nohup bash <skill目录>/scripts/wait_notify.sh "进程匹配模式" \
    -t "XX任务完成" -f "XX任务异常退出" -d "详情" \
    -i 60 > <项目>/run_logs/wait_xxx.log 2>&1 &
```
常用选项：`-s "成功判定命令"`（退出码 0 才算成功，默认进程消失即成功）、`-T 超时秒`、`--dry-run`（测试）。
无需定制即可使用；先 `--dry-run` 验证逻辑再正式部署。

### 步骤 2b：周期监控模式（monitor_template.sh）
1. 复制模板到项目 `run_logs/`（命名如 `monitor_<项目/日期>.sh`），**不要直接修改 skill 目录内的模板**
2. 定制【配置区】：`PROC_PATTERN`（进程 pgrep 模式，多进程用 `|` 连接）、`INTERVAL`（默认 300s）、`TOTAL`（纯进程监控可留 0）、`LOG`（监控日志路径，必填）、`FLOW_LOG`（流程日志路径）、`NEXT_STEP_HINT`（完成后下一步提示）
3. 定制【HOOK 区】`scan_progress()`：**唯一必须定制的函数**，按 `references/monitor-patterns.md` 选择模式实现，写入 `n_done`/`done_list`/`running_item`/`STUCK_METRIC`（多阶段流程另设 `stage`）；`is_all_done()` 一般用默认
4. 冒烟测试：`DRY_RUN=1 bash -n` 语法检查后直接前台跑一轮观察，或缩短 INTERVAL 验证通知写入 LOG
5. 正式部署：`DRY_RUN=0`，`nohup bash monitor_xxx.sh > /dev/null 2>&1 &`（微信输出会记录到 LOG）
6. 验证：确认启动通知已发（或 LOG 有记录）、`pgrep -f monitor_xxx` 存在、`$(LOG).pid` 已生成

### 步骤 3：向用户报告部署结果
- 监控 PID、日志路径、停止方法（`kill <PID>`，流程结束后监控自动退出）
- 将收到哪些通知（启动/逐条目/阶段切换/全部完成/异常中断/卡死预警）

## 运维规则（必须遵守）

1. **运行中的 bash 监控脚本禁止直接编辑**——bash 增量读取脚本文件，编辑会导致字节偏移错乱、执行不可预测。修改流程：`kill <PID>` → 编辑 → `nohup` 重启。
2. **单实例保护**：模板启动时检查 `<LOG>.pid`，若已有存活实例会拒绝启动；改用 `kill` 停止旧实例后再启动。
3. **误报防范**：`ever_seen` 机制——启动后未见过流程进程前不会误报"中断"（允许先启动监控、后启动流程）。
4. **微信频率控制**：骨架已内置——逐条目通知每轮最多一条打包消息；TOTAL>20 时自动每 5 条目一批；卡死预警只发一次。不要在 scan_progress 里另行调用微信发送。

## 通知类型（周期模式骨架内置）

1. 启动通知（含初始进度）
2. 条目完成增量通知（打包，防重发）
3. 阶段切换通知（scan_progress 设置 stage 时启用）
4. 全部完成（附 NEXT_STEP_HINT，随后自动退出）
5. 异常中断（进程消失但未完成，附 FLOW_LOG 路径，随后自动退出）
6. 卡死预警（连续 STUCK_THRESHOLD 轮 STUCK_METRIC 无变化且进程仍在，只发一次）

## 参考文件

- `references/monitor-patterns.md`：六种常见流程的 scan_progress 定制模式（样本文件完整性/文件计数/日志关键字/纯进程/Slurm/多阶段）
- `scripts/monitor_template.sh`：周期监控骨架（含配置区/HOOK 区注释说明）
- `scripts/wait_notify.sh`：简单等待模式（`bash <脚本> --help` 查看用法）

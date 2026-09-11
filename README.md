# AI-Code-repository

AI-assisted programming tool library — 自建的 Claude Code Skills 合集，聚焦植物组学生信分析的场景：流程搭建、标准分析流水线、运行监控与通知。

## 收录的 Skills

| Skill | 用途 | 文档 |
|---|---|---|
| [bash-pipeline-integrator](ClaudeCode%20Skills/bash-pipeline-integrator/) | 将多个独立 bash 脚本整合为模块化、可复用的单脚本流程：集中配置管理、步骤依赖设计、并行执行、统一日志；执行前强制项目评估并生成安全报告 | EN |
| [rnaseq-pipeline](ClaudeCode%20Skills/rnaseq-pipeline/) | 实验室标准 RNA-seq 转录组分析流水线（FastQC → fastp → HISAT2 → featureCounts → DESeq2），含参数化脚本模板（bash/R/Python）、后台运行与微信进度通知 | ZH |
| [pipeline-monitor-notify](ClaudeCode%20Skills/pipeline-monitor-notify/) | 为长周期生信流程部署后台监控：逐样本进度、完成提醒、异常/卡死告警，自动推送到微信；支持单任务等待与多任务周期监控两种模式 | ZH |

## 安装使用

将需要的 skill 目录复制到 Claude Code 的用户级 skills 目录（`~/.claude/skills/`）：

```bash
git clone https://github.com/ErickTong/AI-Code-repository.git
cp -r "AI-Code-repository/ClaudeCode Skills/<skill-name>" ~/.claude/skills/
```

安装后在 Claude Code 中直接描述需求即可自动触发对应 skill，也可通过 `/skill-name` 或 Skill 调用方式手动使用。

## 说明

- 各 skill 的触发条件、工作流程和依赖详见其目录内的 `SKILL.md`
- `rnaseq-pipeline` 与 `pipeline-monitor-notify` 针对实验室服务器环境定制（含微信推送通道），路径类参数需按实际环境调整

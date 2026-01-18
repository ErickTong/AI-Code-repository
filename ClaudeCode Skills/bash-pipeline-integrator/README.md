# Bash Pipeline Integrator

---

**Language:** [English](#english) | [中文](#chinese)

---

<a name="english"></a>
# Bash Pipeline Integrator - User Guide

## Overview

Bash Pipeline Integrator is a tool for integrating multiple independent bash scripts into a modular, reusable single-script pipeline. It is particularly suitable for bioinformatics or data analysis projects, helping to transform scattered scripts into well-organized, maintainable automated workflows.

## Table of Contents

- [Use Cases](#use-cases)
- [Quick Start](#quick-start)
- [Core Features](#core-features)
- [Workflow](#workflow)
- [Configuration](#configuration)
- [Best Practices](#best-practices)
- [FAQ](#faq)
- [Project Structure](#project-structure)

## Use Cases

### When to Use

- **Multi-step bioinformatics pipelines** - e.g., genome annotation, variant detection, RNA-seq analysis
- **Batch data processing workflows** - Processing multiple samples with identical steps
- **Centralized configuration needed** - Duplicate parameters across multiple scripts
- **Parallel execution optimization** - Steps with no dependencies can run in parallel
- **Unified logging and error handling** - Scattered scripts make troubleshooting difficult

### When NOT to Use

- Simple single-step scripts
- Highly flexible exploratory analysis
- Complex dynamic dependencies between steps

## Quick Start

### Basic Workflow

```
1. Project Analysis → Generate assessment report
2. Create Framework → Build script structure
3. Step Migration → Encapsulate independent steps
4. Integration Test → Verify pipeline integrity
```

### Prerequisites

- Bash environment (4.0+ recommended)
- Basic shell scripting knowledge
- Original independent scripts from the project

## Core Features

### 1. Pre-Execution Analysis

Comprehensive project evaluation before any execution:

**Analysis Contents:**
- 📄 Script Analysis - Understand functionality and dependencies of each script
- 📊 Data File Analysis - Check input file formats and sizes
- 🔗 Dependency Analysis - Identify execution order between steps
- 💻 Resource Assessment - Estimate CPU, memory, and storage needs
- ⚠️ Risk Assessment - Identify potential issues and risks

**Safety Rules:**
- ✅ Read-first approach - No file modifications during analysis
- ✅ Output protection - Use timestamps or version numbers for new outputs
- ✅ Backup protection - Auto-backup important files before modification
- ❌ No auto-deletion - Unless explicitly requested by user

### 2. Centralized Configuration

Manage scattered configurations in one place:

```bash
# ==================== CONFIGURATION ====================

# Project Configuration
PROJECT_NAME="ProjectName"
WORKING_DIR=""

# Input Configuration
INPUT_FILE="path/to/input.fasta"

# Tool Parameters
THREADS_DEFAULT=16
EVALUE="1e-5"

# Pipeline Control
RUN_STEP_1=true
RUN_STEP_2=true
RUN_PARALLEL=true
```

### 3. Modular Step Design

Each analysis step encapsulated as an independent function:

```bash
# Step N: Sequence Validation and Cleaning
step_check_fasta() {
    [[ "${RUN_CHECK_FASTA}" != "true" ]] && return 0

    info "=========================================="
    info "Step N: Sequence Validation and Cleaning"
    info "=========================================="

    # Main logic
    validate_fasta "${INPUT_FILE}"

    # Check result
    if [[ $? -eq 0 ]]; then
        info "Step N completed"
        return 0
    else
        log_error "Step N failed"
        return 1
    fi
}
```

### 4. Parallel Execution Optimization

Choose execution mode based on resources:

```bash
if [[ "${RUN_PARALLEL}" == "true" ]]; then
    # Parallel execution for independent steps
    step_function_1 & pid1=$!
    step_function_2 & pid2=$!
    wait ${pid1}
    wait ${pid2}
else
    # Sequential execution for all steps
    step_function_1
    step_function_2
fi
```

### 5. Unified Logging System

Record all operations to log files:

```bash
# Output to both terminal and log file
log() {
    echo -e "\e[32m[INFO]\e[0m $@" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "\e[31m[ERROR]\e[0m $@" | tee -a "${ERROR_LOG_FILE}"
}
```

### 6. Notification Mechanism

Auto-notify for long-running tasks:

```bash
notify "step start"    # Step begins
notify "step completed" # Step completes
```

## Workflow

### Step 1: Project Analysis

Perform pre-execution analysis and generate assessment report:

```bash
# 1. Identify all script files
find . -name "*.sh" -type f | sort

# 2. Analyze each script
#    - Functionality and purpose
#    - Input and output
#    - Dependencies

# 3. Build dependency graph
#    Determine execution order

# 4. Generate assessment report
#    PROJECT_ASSESSMENT.md
```

### Step 2: Create Framework

Create main script framework:

```bash
# 00run_all_cc.sh
#!/bin/bash

# 1. Configuration section
# 2. Utility functions
# 3. Step functions
# 4. Main pipeline
```

### Step 3: Step Migration

Encapsulate each independent script as a function:

```bash
# Original: 01_step.sh
# Convert to: step_01_function()
```

### Step 4: Integration Test

Test pipeline integrity and correctness:

- ✅ Test individual step functionality
- ✅ Test sequential execution mode
- ✅ Test parallel execution mode
- ✅ Test error handling and recovery

## Configuration

### Configuration Categories

| Category | Description | Examples |
|----------|-------------|----------|
| Project | Project name, working directory | `PROJECT_NAME`, `WORKING_DIR` |
| Input | Input file paths | `INPUT_FILE`, `INPUT_DIR` |
| Database | Database paths | `DB_EGGNOG`, `DB_NR` |
| Tool | Tool parameters | `THREADS_DEFAULT`, `EVALUE` |
| Control | Step switches, parallel control | `RUN_STEP_1`, `RUN_PARALLEL` |

### Naming Conventions

- `RUN_` - Boolean flags for step execution
- `THREADS_` - Thread count configuration
- `DB_` - Database paths
- `INPUT_` - Input configuration
- `OUTPUT_` - Output configuration

## Best Practices

### 1. Path Handling

```bash
# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Handle relative paths
[[ ! "${INPUT_FILE}" =~ ^/ ]] && INPUT_FILE="${SCRIPT_DIR}/${INPUT_FILE}"
```

### 2. Error Handling

```bash
set -euo pipefail  # Strict mode

# Check function return status
step_function || {
    log_error "Step failed"
    exit 1
}
```

### 3. Conditional Execution

```bash
# Control via configuration
[[ "${RUN_THIS_STEP}" != "true" ]] && return 0

# File existence check
[[ -f "${FILE}" ]] && do_something || warn "File not found"
```

### 4. Logging

```bash
# Log with timestamp
log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@"
}
```

## FAQ

**Q1: How to choose between parallel and sequential execution?**

A:
- **Parallel execution** - High-performance computing servers, steps with no dependencies
- **Sequential execution** - Resource-constrained environments, or strict dependencies

**Q2: How to handle long-running tasks?**

A:
- Use background processes: `command &`
- Record process ID: `pid=$!`
- Wait for completion: `wait ${pid}`
- Enable notification mechanism

**Q3: How to debug modular scripts?**

A:
- Disable other steps, run only target step
- Use `bash -x script.sh` to trace execution
- Check log files for detailed error information

**Q4: How to ensure script portability?**

A:
- Avoid hardcoded absolute paths
- Use relative paths or configuration variables
- Provide clear configuration templates

**Q5: How to add new analysis steps?**

A:
1. Add step control variable in configuration section
2. Create new step function
3. Add call logic in main pipeline

## Project Structure

```
bash-pipeline-integrator/
├── SKILL.md                      # Skill definition
├── README.md                     # This file - User Guide
└── references/                   # Reference documents
    ├── project-analysis-workflow.md    # Project analysis workflow
    ├── framework-creation.md           # Framework creation guide
    ├── step-migration.md              # Step migration guide
    ├── testing-guide.md               # Testing guide
    ├── configuration-templates.md      # Configuration templates
    └── best-practices.md              # Best practices
```

---

[↑ Back to Language Selection](#bash-pipeline-integrator)

---

<a name="chinese"></a>
# Bash Pipeline Integrator - 使用说明

## 概述

Bash Pipeline Integrator 是一个用于将多个独立的 bash 脚本整合为模块化、可复用的单脚本流程的工具。特别适用于生信分析或数据处理项目，帮助将分散的脚本转换为结构清晰、易于维护的自动化流程。

## 目录

- [适用场景](#适用场景-1)
- [快速开始](#快速开始-1)
- [核心功能](#核心功能-1)
- [详细工作流程](#详细工作流程-1)
- [配置说明](#配置说明-1)
- [最佳实践](#最佳实践-1)
- [常见问题](#常见问题-1)
- [项目结构](#项目结构-1)

## 适用场景

### 适合使用的情况

- **多步骤生信分析流程** - 如基因组注释、变异检测、RNA-seq 分析等
- **数据批处理流水线** - 需要对多个样本执行相同处理步骤
- **需要集中配置管理** - 多个脚本中有重复的配置参数
- **需要并行执行优化** - 步骤间无依赖关系，可以并行运行
- **需要统一日志和错误处理** - 分散的脚本难以追踪问题

### 不适合使用的情况

- 简单的单步骤脚本
- 需要高度灵活性的探索性分析
- 步骤间存在复杂的动态依赖关系

## 快速开始

### 基本使用流程

```
1. 项目分析 → 生成评估报告
2. 创建框架 → 搭建脚本结构
3. 步骤迁移 → 封装独立步骤
4. 整合测试 → 验证流程完整性
```

### 前置条件

- Bash 环境 (建议 4.0+)
- 基本的 shell 脚本编写能力
- 原始项目中的各个独立脚本

## 核心功能

### 1. 执行前置分析

在执行任何脚本前，自动进行完整的项目评估：

**分析内容：**
- 📄 脚本文件分析 - 理解每个脚本的功能和依赖
- 📊 数据文件分析 - 检查输入文件格式和大小
- 🔗 依赖关系分析 - 识别步骤间的执行顺序
- 💻 资源需求评估 - 估算 CPU、内存、存储需求
- ⚠️ 风险评估 - 识别潜在问题和风险点

**安全规则：**
- ✅ 只读操作优先 - 分析阶段不修改任何文件
- ✅ 输出保护策略 - 使用时间戳或版本号区分新输出
- ✅ 备份保护 - 重要文件修改前自动备份
- ❌ 禁止自动删除 - 除非用户明确要求

### 2. 集中化配置

将分散在各个脚本中的配置集中管理：

```bash
# ==================== 配置区域 / CONFIGURATION ====================

# 项目配置
PROJECT_NAME="项目名称"
WORKING_DIR=""

# 输入配置
INPUT_FILE="path/to/input.fasta"

# 工具参数配置
THREADS_DEFAULT=16
EVALUE="1e-5"

# 流程控制
RUN_STEP_1=true
RUN_STEP_2=true
RUN_PARALLEL=true
```

**配置原则：**
- 核心必要的输入参数放在配置中
- 可自动推导的参数根据核心输入自动调整
- 不确定的参数提示用户修改

### 3. 模块化步骤设计

每个分析步骤封装为独立函数：

```bash
# 步骤N: 序列验证与清理
step_check_fasta() {
    [[ "${RUN_CHECK_FASTA}" != "true" ]] && return 0

    info "=========================================="
    info "步骤N: 序列验证与清理"
    info "=========================================="

    # 执行主要逻辑
    validate_fasta "${INPUT_FILE}"

    # 检查执行结果
    if [[ $? -eq 0 ]]; then
        info "步骤N完成"
        return 0
    else
        log_error "步骤N失败"
        return 1
    fi
}
```

**设计原则：**
- 单一职责 - 每个函数只做一件事
- 清晰命名 - 函数名表达功能意图
- 错误处理 - 内部处理错误并返回状态
- 配置控制 - 通过配置开关控制执行

### 4. 并行执行优化

根据资源条件选择执行模式：

```bash
if [[ "${RUN_PARALLEL}" == "true" ]]; then
    # 并行执行独立步骤
    step_function_1 & pid1=$!
    step_function_2 & pid2=$!
    wait ${pid1}
    wait ${pid2}
else
    # 顺序执行所有步骤
    step_function_1
    step_function_2
fi
```

### 5. 统一日志系统

所有操作记录到日志文件：

```bash
# 同时输出到终端和日志文件
log() {
    echo -e "\e[32m[INFO]\e[0m $@" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "\e[31m[ERROR]\e[0m $@" | tee -a "${ERROR_LOG_FILE}"
}
```

**日志结构：**
```
logs/
├── pipeline_20250118.log      # 主流程日志
└── pipeline_errors_20250118.log # 错误日志
```

### 6. 通知机制

长时间运行任务自动通知完成状态：

```bash
notify "step start"    # 步骤开始
notify "step completed" # 步骤完成
```

## 详细工作流程

### 第一步：项目分析

执行前置分析，生成评估报告：

```bash
# 1. 识别所有脚本文件
find . -name "*.sh" -type f | sort

# 2. 分析每个脚本
#    - 功能和用途
#    - 输入输出
#    - 依赖关系

# 3. 构建依赖图
#    确定执行顺序

# 4. 生成评估报告
#    PROJECT_ASSESSMENT.md
```

### 第二步：创建框架

创建主脚本框架：

```bash
# 00run_all_cc.sh
#!/bin/bash

# 1. 配置区域
# 2. 工具函数
# 3. 步骤函数
# 4. 主流程
```

### 第三步：步骤迁移

将每个独立脚本封装为函数：

```bash
# 原始脚本: 01_step.sh
# 转换为: step_01_function()
```

### 第四步：整合测试

测试流程的完整性和正确性：

- ✅ 测试单独步骤功能
- ✅ 测试顺序执行模式
- ✅ 测试并行执行模式
- ✅ 测试错误处理和恢复

## 配置说明

### 配置分类

| 分类 | 说明 | 示例 |
|-----|------|------|
| 项目配置 | 项目名称、工作目录 | `PROJECT_NAME`, `WORKING_DIR` |
| 输入配置 | 输入文件路径 | `INPUT_FILE`, `INPUT_DIR` |
| 数据库配置 | 数据库路径 | `DB_EGGNOG`, `DB_NR` |
| 工具配置 | 工具参数 | `THREADS_DEFAULT`, `EVALUE` |
| 流程控制 | 步骤开关、并行控制 | `RUN_STEP_1`, `RUN_PARALLEL` |

### 命名约定

- `RUN_` - 布尔标志，控制步骤执行
- `THREADS_` - 线程数配置
- `DB_` - 数据库路径
- `INPUT_` - 输入配置
- `OUTPUT_` - 输出配置

## 最佳实践

### 1. 路径处理

```bash
# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 处理相对路径
[[ ! "${INPUT_FILE}" =~ ^/ ]] && INPUT_FILE="${SCRIPT_DIR}/${INPUT_FILE}"
```

### 2. 错误处理

```bash
set -euo pipefail  # 严格模式

# 函数返回状态检查
step_function || {
    log_error "步骤失败"
    exit 1
}
```

### 3. 条件执行

```bash
# 通过配置控制
[[ "${RUN_THIS_STEP}" != "true" ]] && return 0

# 文件存在检查
[[ -f "${FILE}" ]] && do_something || warn "文件不存在"
```

### 4. 日志记录

```bash
# 带时间戳的日志
log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@"
}
```

## 常见问题

**Q1: 如何选择并行还是顺序执行？**

A:
- **并行执行** - 适用于高性能计算服务器，步骤间无依赖关系
- **顺序执行** - 适用于资源受限环境，或步骤间有严格依赖

**Q2: 如何处理长时间运行的任务？**

A:
- 使用后台进程：`command &`
- 记录进程 ID：`pid=$!`
- 等待完成：`wait ${pid}`
- 启用通知机制

**Q3: 如何调试模块化脚本？**

A:
- 禁用其他步骤，只运行目标步骤
- 使用 `bash -x script.sh` 跟踪执行
- 查看日志文件获取详细错误信息

**Q4: 如何确保脚本可迁移性？**

A:
- 避免硬编码绝对路径
- 使用相对路径或配置变量
- 提供清晰的配置模板

**Q5: 如何添加新的分析步骤？**

A:
1. 在配置区域添加步骤控制变量
2. 创建新的步骤函数
3. 在主流程中添加调用逻辑

## 项目结构

```
bash-pipeline-integrator/
├── SKILL.md                      # 技能定义文件
├── README.md                     # 本文件 - 使用说明
└── references/                   # 参考文档
    ├── project-analysis-workflow.md    # 项目分析流程
    ├── framework-creation.md           # 框架创建指南
    ├── step-migration.md              # 步骤迁移指南
    ├── testing-guide.md               # 测试指南
    ├── configuration-templates.md      # 配置模板
    └── best-practices.md              # 最佳实践
```

---

[↑ 返回语言选择](#bash-pipeline-integrator)

---

## License

See LICENSE.txt for complete terms.

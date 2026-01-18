---
name: bash-pipeline-integrator
description: Guide for integrating multiple independent bash scripts into a modular, reusable single-script pipeline for bioinformatics or data analysis projects. Use when working with multi-step analysis workflows that need centralized configuration management, modular step design with clear dependencies, parallel execution support, unified logging and error handling, and safe execution with pre-analysis validation.
license: Complete terms in LICENSE.txt
---

# Bash Pipeline Integrator

This skill provides a comprehensive guide for integrating multiple independent bash scripts into a single, modular, and reusable pipeline script.

## Overview

Transform scattered, hard-to-maintain bash script workflows into well-organized, production-ready pipelines with centralized configuration, modular steps, parallel execution, and robust error handling.

## Core Principles

### Pre-Execution Analysis and Safety

**CRITICAL: Before executing any script or command, perform a comprehensive analysis and evaluation of the current project.**

**Analysis Process:**

1. **Script Analysis**
   - Read and parse all script files
   - Understand functionality, dependencies, and execution logic
   - Identify configuration parameters and input/output paths

2. **Data File Analysis**
   - Check input file existence and size
   - For files >10M, use `head -n 20` to understand format and content
   - Skip unreadable formats and log the issue
   - Analyze data types, formats, and content structure

3. **Project Evaluation and Planning**
   - Summarize overall project architecture from script and data information
   - Identify analysis step dependencies and execution order
   - Assess required computational resources (CPU, memory, storage)
   - Identify potential risks and issues

4. **Generate Assessment Report**
   - Create project parsing and evaluation file (e.g., `PROJECT_ASSESSMENT.md`)
   - Document project structure, script functions, data info, execution plan
   - List all dependencies and environment requirements
   - Provide risk assessment and recommendations

**Execution Rules:**
- **MUST** obtain explicit user approval after reviewing the assessment report before executing scripts
- Prohibit automatic execution of commands that may affect data or systems
- Present all analysis results as reports for user decision-making

### Safety Rules

**File Safety Rules:**

1. **Prohibit Deleting Existing Files**
   - Strictly prohibit deleting any existing files (e.g., `rm`, `rm -rf` commands)
   - Only delete when user explicitly requests specific file deletion
   - Obtain user confirmation before cleaning temporary files
   - All modifications create new scripts or files

2. **Read-First Approach**
   - Default to read-only operations during analysis phase
   - Use read-only commands: `cat`, `head`, `tail`, `grep`, etc.

3. **Output File Renaming Strategy**
   - Use timestamps or version numbers for regenerated output files
   - Example: `output_v1.txt`, `output_v2_20250116.txt`
   - Preserve historical results for comparison and rollback

4. **Backup Protection**
   - Backup important input and configuration files before modification
   - Backup naming convention: `filename.backup_YYYYMMDD`

**System Safety Rules:**

1. **Permission Check**
   - Verify sufficient permissions before executing commands
   - Avoid `sudo` and privileged commands unless absolutely necessary

2. **Command Review**
   - List all commands to execute in the assessment report
   - Clearly state each command's purpose and expected result
   - Execute only after user confirmation

3. **Resource Limits**
   - Evaluate potential system resource consumption
   - Avoid commands that may overload the system
   - Use appropriate resource limit parameters (e.g., `--threads`, `--memory`)

## Integration Approach

### 1. Centralized Configuration

**Goal:** Centralize scattered configurations from individual scripts into one location for easy management.

**Implementation:**
- Define configuration variable section at script beginning
- Organize configurations by category (project, input, database, scripts, pipeline control)
- Add Chinese comments for each configuration item
- Keep core and necessary inputs in config; auto-adjust others based on core inputs; ask user to modify uncertain parameters

**Benefits:**
- Modify configuration in one place only
- Easy for beginners to find parameters to modify
- Clear and explicit configuration purposes

### 2. Modular Step Design

**Goal:** Divide analysis pipeline into independent functional modules, each with single responsibility.

**Module Division:**
```
step_prepare_database()    # Database preparation
step_check_fasta()         # Sequence validation and cleaning
step_run_emapper()         # EggNOG-mapper annotation
step_run_interpro()        # InterProScan analysis
step_run_nr()              # NR database search
step_run_uniprot()         # UniProt database search
step_statistics()          # Statistical analysis and visualization
```

**Design Principles:**
- Each function does one thing
- Function names clearly express intent
- Functions handle errors internally and return status
- Control execution via configuration switches

### 3. Parallel and Sequential Execution Control

**Goal:** Improve computational resource utilization and reduce total runtime.

**Implementation:**
- Control parallel mode via configuration variable `RUN_PARALLEL`
- Execute independent steps in parallel
- Execute dependent steps sequentially
- Use `&` to start background processes, `wait` for completion

**Use Cases:**
- High-performance computing servers - enable parallel
- Resource-constrained environments - disable parallel, execute sequentially

### 4. Unified Logging System

**Goal:** Centrally record all operations and errors for easy troubleshooting.

**Implementation:**
- Define logging functions `log()` and `log_error()`
- Write output to both terminal and log file simultaneously
- Name log files by date for traceability
- Color-coded output for readability (green-INFO, yellow-WARN, red-ERROR)

**Log Structure:**
```
logs/
├── pipeline_20250116.log      # Main pipeline log
└── pipeline_errors_20250116.log # Error log
```

### 5. Notification Mechanism

**Goal:** Send timely notifications for long-running tasks.

**Implementation:**
- Define `notify()` function calling external notification script
- Send notifications at key step start and end
- Control notification script path via configuration variable

### 6. Input Validation and Environment Check

**Goal:** Verify all prerequisites before execution to avoid mid-process failures.

**Check Items:**
- Existence of required commands and scripts
- Existence of Singularity containers
- Existence of input files
- Availability of database source files

## Workflow Decision Tree

1. **Analyze Project Structure**
   - Start with: See [Project Analysis Workflow](references/project-analysis-workflow.md)
   - Identify all analysis steps, dependencies, and configuration parameters

2. **Create Pipeline Framework**
   - Start with: See [Framework Creation](references/framework-creation.md)
   - Create main script with configuration section and tool functions

3. **Migrate Each Step**
   - Start with: See [Step Migration](references/step-migration.md)
   - Extract core commands and wrap as modular functions

4. **Integration and Testing**
   - Start with: See [Testing Guide](references/testing-guide.md)
   - Test individual steps, sequential/parallel modes, error handling

## Resources

### scripts/
Executable code for pipeline integration tasks.

**Appropriate for:**
- Python scripts for project analysis
- Bash helper functions for common operations
- Validation scripts for checking pipeline structure

### references/
Detailed documentation for specific integration scenarios.

**See:**
- [Project Analysis Workflow](references/project-analysis-workflow.md) - Step-by-step project structure analysis
- [Framework Creation](references/framework-creation.md) - Creating the main pipeline script framework
- [Step Migration](references/step-migration.md) - Migrating individual scripts to modular functions
- [Testing Guide](references/testing-guide.md) - Testing procedures for the integrated pipeline
- [Configuration Templates](references/configuration-templates.md) - Ready-to-use configuration section templates
- [Best Practices](references/best-practices.md) - Common patterns and anti-patterns

### assets/
Files used in pipeline output but not loaded into context.

**Appropriate for:**
- Bash script templates
- Configuration file examples
- Pipeline workflow diagrams

---

Delete unused directories after customizing. Not every pipeline integration requires all three types of resources.

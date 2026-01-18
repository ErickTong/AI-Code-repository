# Framework Creation

This guide explains how to create the main pipeline script framework.

## Basic Script Structure

```bash
#!/bin/bash
set -euo pipefail

################################################################################
# Configuration Section
################################################################################

# Project Configuration
PROJECT_NAME="MyPipeline"
WORKING_DIR=""
OUTPUT_PREFIX=""

# Input Configuration
INPUT_FILE="path/to/input.fasta"

# Database Configuration
DB_SOURCE=""

# Tool Configuration
THREADS_DEFAULT=16
EVALUE="1e-5"

# Pipeline Control
RUN_PARALLEL=true

################################################################################
# Tool Functions
################################################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging functions
log() {
    echo -e "\033[0;32m[INFO]\033[0m $@" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $@" | tee -a "${LOG_FILE}"
}

warn() {
    echo -e "\033[0;33m[WARN]\033[0m $@" | tee -a "${LOG_FILE}"
}

notify() {
    local message="$1"
    if [[ -n "${NOTIFY_SCRIPT:-}" ]]; then
        bash "${NOTIFY_SCRIPT}" "${message}" 2>/dev/null || true
    fi
}

################################################################################
# Validation Functions
################################################################################

validate_setup() {
    log "Validating setup..."

    # Check input file
    if [[ ! -f "${INPUT_FILE}" ]]; then
        log_error "Input file not found: ${INPUT_FILE}"
        return 1
    fi

    # Check required commands
    local required_commands=("bash" "awk" "sed")
    for cmd in "${required_commands[@]}"; do
        command -v "${cmd}" &> /dev/null || {
            log_error "Required command not found: ${cmd}"
            return 1
        }
    done

    # Create output directories
    mkdir -p "${WORKING_DIR}/logs"
    mkdir -p "${WORKING_DIR}/output"

    log "Setup validation passed"
    return 0
}

################################################################################
# Step Functions
################################################################################

# Example step function
step_example() {
    [[ "${RUN_STEP_EXAMPLE:-true}" != "true" ]] && return 0

    log "=========================================="
    log "Step: Example Step"
    log "=========================================="

    notify "Example step started"

    # Execute main logic
    command_to_run

    # Check result
    if [[ $? -eq 0 ]]; then
        log "Example step completed"
        notify "Example step completed"
    else
        log_error "Example step failed"
        return 1
    fi
}

################################################################################
# Main Pipeline
################################################################################

main() {
    local start_time=$(date +%s)

    # Setup logging
    LOG_FILE="${WORKING_DIR}/logs/pipeline_$(date +%Y%m%d).log"

    # Validate setup
    validate_setup || exit 1

    # Execute steps
    local failed=0

    if [[ "${RUN_PARALLEL}" == "true" ]]; then
        # Parallel execution
        step_step1 & pid1=$!
        step_step2 & pid2=$!
        wait ${pid1} || failed=1
        wait ${pid2} || failed=1

        # Sequential steps
        step_step3 || failed=1
    else
        # Sequential execution
        step_step1 || failed=1
        step_step2 || failed=1
        step_step3 || failed=1
    fi

    # Summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [[ ${failed} -eq 0 ]]; then
        log "Pipeline completed in ${duration} seconds"
    else
        log_error "Pipeline failed"
        exit 1
    fi
}

main "$@"
```

## Configuration Section Template

```bash
################################################################################
# ==================== Configuration Section ====================
################################################################################

# ==================== Project Configuration ====================
PROJECT_NAME="GenomeAnnotation"
WORKING_DIR="${SCRIPT_DIR}"
OUTPUT_PREFIX="${PROJECT_NAME}"

# ==================== Input Configuration ====================
INPUT_FILE="input/sequences.fasta"

# ==================== Database Configuration ====================
DB_EGGNOG="/data/databases/eggnog"
DB_INTERPRO="/data/databases/interpro"
DB_NR="/data/databases/nr"
DB_UNIPROT="/data/databases/uniprot"

# ==================== Tool Configuration ====================
THREADS_DEFAULT=16
THREADS_DIAMOND=36
THREADS_EMAPPER=36
EVALUE="1e-5"
MAX_TARGET_SEQS=1

# ==================== Notification Configuration ====================
NOTIFY_SCRIPT="/path/to/remind.sh"

# ==================== Pipeline Control ====================
RUN_PREPARE_DATABASE=true
RUN_CHECK_FASTA=true
RUN_EMAPPER=true
RUN_INTERPRO=true
RUN_NR=true
RUN_UNIPROT=true
RUN_STATISTICS=true
RUN_PARALLEL=true
```

## Helper Function Library

### Path Handling

```bash
# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Handle relative paths
[[ ! "${INPUT_FILE}" =~ ^/ ]] && INPUT_FILE="${SCRIPT_DIR}/${INPUT_FILE}"
```

### Error Handling

```bash
set -euo pipefail  # Strict mode

# Function return status check
step_function() {
    command_to_run
    return $?
}

# Check return value
step_function || {
    log_error "Step failed"
    exit 1
}
```

### Conditional Execution

```bash
# Control via configuration
[[ "${RUN_THIS_STEP}" != "true" ]] && return 0

# File existence check
[[ -f "${FILE}" ]] && do_something || warn "File not found"

# Command existence check
command -v "command_name" &> /dev/null || {
    error "Required command not found"
    exit 1
}
```

### Logging with Timestamps

```bash
log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" | tee -a "${LOG_FILE}"
}
```

## Framework Creation Checklist

- [ ] Configuration section created
- [ ] Tool functions implemented (log, error, notify)
- [ ] Validation functions created
- [ ] Step function templates added
- [ ] Main pipeline control flow implemented
- [ ] Parallel/sequential execution modes supported
- [ ] Error handling in place
- [ ] Logging system functional

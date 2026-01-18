# Step Migration Guide

This guide explains how to migrate individual bash scripts into modular step functions.

## Migration Process

For each original script, follow these steps:

### 1. Extract Core Commands

Read the original script and identify:
- The main analytical commands
- Data processing steps
- Output generation commands

### 2. Create Step Function Template

```bash
################################################################################
# Step: [Step Name]
################################################################################
step_function_name() {
    # Check if step should run
    [[ "${RUN_THIS_STEP:-true}" != "true" ]] && return 0

    log "=========================================="
    log "Step: [Step Name]"
    log "=========================================="

    notify "Step started"

    # Define step-specific variables
    local input_file="${INPUT_FILE}"
    local output_file="${WORKING_DIR}/output/step_output.txt"

    # Execute main logic
    [CORE COMMANDS HERE]

    # Check execution result
    if [[ $? -eq 0 ]]; then
        log "Step completed"
        notify "Step completed"
    else
        log_error "Step failed"
        return 1
    fi
}
```

### 3. Hardcode to Configuration

Replace hardcoded values with configuration variables:

**Before:**
```bash
diamond blastx -d /data/databases/nr.dmnd -q input.fasta -o output.txt
```

**After:**
```bash
diamond blastx \
    -d "${DB_NR}/nr.dmnd" \
    -q "${INPUT_FILE}" \
    -o "${WORKING_DIR}/output/nr_results.txt" \
    -p "${THREADS_DIAMOND}" \
    -e "${EVALUE}"
```

### 4. Add Error Handling

```bash
# Check input files
if [[ ! -f "${input_file}" ]]; then
    log_error "Input file not found: ${input_file}"
    return 1
fi

# Check required tools
command -v "diamond" &> /dev/null || {
    log_error "Diamond not found"
    return 1
}

# Create output directory
mkdir -p "$(dirname "${output_file}")"

# Execute with error checking
command_to_run || {
    log_error "Command failed: command_to_run"
    return 1
}
```

### 5. Add Logging

```bash
log "Starting diamond blastx with database: ${DB_NR}"

# Run command
diamond blastx \
    -d "${DB_NR}/nr.dmnd" \
    -q "${INPUT_FILE}" \
    -o "${WORKING_DIR}/output/nr_results.txt" \
    -p "${THREADS_DIAMOND}" \
    -e "${EVALUE}"

if [[ $? -eq 0 ]]; then
    log "Diamond blastx completed successfully"
    log "Output written to: ${WORKING_DIR}/output/nr_results.txt"
else
    log_error "Diamond blastx failed"
    return 1
fi
```

## Example: Migrating a Diamond BLAST Step

### Original Script (01_run_diamond.sh)

```bash
#!/bin/bash
input="sequences.fasta"
output="diamond_results.txt"
db="/data/databases/nr.dmnd"

diamond blastx -d $db -q $input -o $output -p 16 -e 1e-5
```

### Migrated Step Function

```bash
################################################################################
# Step: Run Diamond BLAST against NR Database
################################################################################
step_run_nr() {
    [[ "${RUN_NR:-true}" != "true" ]] && return 0

    log "=========================================="
    log "Step: Diamond BLAST against NR Database"
    log "=========================================="

    notify "Diamond BLAST started"

    # Validate inputs
    local input_file="${INPUT_FILE}"
    local output_file="${WORKING_DIR}/output/nr_results.txt"
    local db_file="${DB_NR}/nr.dmnd"

    if [[ ! -f "${input_file}" ]]; then
        log_error "Input file not found: ${input_file}"
        return 1
    fi

    if [[ ! -f "${db_file}" ]]; then
        log_error "Database file not found: ${db_file}"
        return 1
    fi

    command -v diamond &> /dev/null || {
        log_error "Diamond command not found"
        return 1
    }

    # Create output directory
    mkdir -p "$(dirname "${output_file}")"

    # Run Diamond BLAST
    log "Running Diamond BLAST with ${THREADS_DIAMOND} threads"
    log "Database: ${db_file}"
    log "E-value threshold: ${EVALUE}"

    diamond blastx \
        -d "${db_file}" \
        -q "${input_file}" \
        -o "${output_file}" \
        -p "${THREADS_DIAMOND}" \
        -e "${EVALUE}" \
        --outfmt 6 \
        --max-target-seqs ${MAX_TARGET_SEQS:-1}

    if [[ $? -eq 0 ]]; then
        log "Diamond BLAST completed successfully"
        log "Output written to: ${output_file}"
        notify "Diamond BLAST completed"
    else
        log_error "Diamond BLAST failed"
        return 1
    fi
}
```

## Parallel Execution Setup

For independent steps, add to main function:

```bash
if [[ "${RUN_PARALLEL}" == "true" ]]; then
    # Run independent steps in parallel
    step_run_emapper & pid1=$!
    step_run_interpro & pid2=$!
    step_run_nr & pid3=$!

    # Wait for all parallel steps
    wait ${pid1} || failed=1
    wait ${pid2} || failed=1
    wait ${pid3} || failed=1

    # Check if any failed
    [[ ${failed} -eq 1 ]] && return 1
fi
```

## Sequential Execution Setup

For dependent steps:

```bash
# Step 1 must complete before step 2
step_check_fasta || failed=1
step_run_emapper || failed=1

# Step 3 and 4 can run in parallel
step_run_interpro & pid3=$!
step_run_nr & pid4=$!
wait ${pid3} || failed=1
wait ${pid4} || failed=1

# Step 5 depends on 3 and 4
step_statistics || failed=1
```

## Migration Checklist

For each script:
- [ ] Core commands extracted
- [ ] Step function created
- [ ] Hardcoded paths replaced with config variables
- [ ] Input validation added
- [ ] Tool availability check added
- [ ] Error handling implemented
- [ ] Logging added at key points
- [ ] Output directory creation added
- [ ] Success/failure notifications added
- [ ] Configuration switch added
- [ ] Step tested independently

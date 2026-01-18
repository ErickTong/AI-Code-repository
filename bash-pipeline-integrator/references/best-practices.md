# Best Practices

This guide covers common patterns, anti-patterns, and best practices for bash pipeline integration.

## Path Handling

### Good: Relative Paths with Script Directory

```bash
# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use relative paths
INPUT_FILE="${SCRIPT_DIR}/input/data.fasta"
OUTPUT_DIR="${SCRIPT_DIR}/output"
```

### Bad: Absolute Hardcoded Paths

```bash
# ❌ Hardcoded absolute paths
INPUT_FILE="/home/user/projects/genome_analysis/input/data.fasta"
OUTPUT_DIR="/home/user/projects/genome_analysis/output"
```

### Good: Configurable Paths

```bash
# Allow user to override
WORKING_DIR="${WORKING_DIR:-${SCRIPT_DIR}}"
INPUT_FILE="${INPUT_FILE:-${WORKING_DIR}/input/data.fasta}"
```

## Error Handling

### Good: Proper Error Handling

```bash
set -euo pipefail  # Enable strict mode

step_function() {
    # Validate inputs
    [[ ! -f "${INPUT_FILE}" ]] && {
        log_error "Input not found: ${INPUT_FILE}"
        return 1
    }

    # Run command and check status
    command_to_run || {
        log_error "Command failed: command_to_run"
        return 1
    }

    return 0
}

# Check return value
step_function || exit 1
```

### Bad: No Error Handling

```bash
# ❌ No validation, no error checking
step_function() {
    command_to_run
}
```

## Logging

### Good: Structured Logging

```bash
log() {
    echo -e "\033[0;32m[INFO]\033[0m $@" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $@" | tee -a "${LOG_FILE}"
}

warn() {
    echo -e "\033[0;33m[WARN]\033[0m $@" | tee -a "${LOG_FILE}"
}
```

### Bad: Inconsistent Logging

```bash
# ❌ Direct echo without context
echo "Running command..."
echo "Error!"
echo "Done."
```

## Variable Naming

### Good: Descriptive Names

```bash
# Clear and descriptive
THREADS_DEFAULT=16
THREADS_DIAMOND=36
INPUT_FASTA_FILE="sequences.fasta"
OUTPUT_TSV_FILE="results.tsv"
```

### Bad: Cryptic Names

```bash
# ❌ Unclear abbreviations
td=16
diam=36
inf="sequences.fasta"
out="results.tsv"
```

## Step Design

### Good: Single Responsibility

```bash
# Each function does one thing
step_validate_input() {
    # Only validates input
}

step_prepare_database() {
    # Only prepares database
}

step_run_annotation() {
    # Only runs annotation
}
```

### Bad: Multiple Responsibilities

```bash
# ❌ Does too many things
step_all() {
    validate_input
    prepare_database
    run_annotation
    generate_stats
    create_plots
}
```

## Parallel Execution

### Good: Managed Parallelism

```bash
if [[ "${RUN_PARALLEL}" == "true" ]]; then
    # Run independent steps in parallel
    step_emapper & pid1=$!
    step_interpro & pid2=$!
    step_nr & pid3=$!

    # Wait for completion
    wait ${pid1} || failed=1
    wait ${pid2} || failed=1
    wait ${pid3} || failed=1

    # Stop if any failed
    [[ ${failed} -eq 1 ]] && return 1
fi
```

### Bad: Uncontrolled Parallelism

```bash
# ❌ No control, no error checking
step_emapper &
step_interpro &
step_nr &
```

## Configuration Management

### Good: Centralized Configuration

```bash
# All config at the top
CONFIG_PROJECT_NAME="Project"
CONFIG_THREADS=16
CONFIG_EVALUE="1e-5"

# Used throughout
step1() {
    use ${CONFIG_THREADS}
}

step2() {
    use ${CONFIG_THREADS}
}
```

### Bad: Scattered Configuration

```bash
# ❌ Config spread throughout script
step1() {
    local threads=16
}

step2() {
    local threads=8  # Different value!
}

step3() {
    local threads=16  # Another value!
}
```

## File Operations

### Good: Safe File Operations

```bash
# Create new file with timestamp
OUTPUT_FILE="output_v${TIMESTAMP}.txt"

# Backup before modification
[[ -f "${CONFIG_FILE}" ]] && cp "${CONFIG_FILE}" "${CONFIG_FILE}.backup"

# Check existence before reading
[[ -f "${INPUT_FILE}" ]] && read_data "${INPUT_FILE}"
```

### Bad: Destructive Operations

```bash
# ❌ Overwrites without checking
echo "data" > output.txt

# ❌ Deletes without confirmation
rm -rf temp/*

# ❌ No backup before modification
sed -i 's/old/new/g' config.conf
```

## Resource Management

### Good: Resource Awareness

```bash
# Detect available resources
CPU_COUNT=$(nproc)
MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')

# Adjust based on available resources
THREADS_DEFAULT=$((CPU_COUNT / 2))
if [[ ${MEMORY_GB} -ge 32 ]]; then
    THREADS_DEFAULT=${CPU_COUNT}
fi

# Resource limits in commands
diamond blastx -p ${THREADS_DEFAULT} -b 4G input.fasta
```

### Bad: Resource Blindness

```bash
# ❌ Always uses fixed resources
diamond blastx -p 64 input.fasta  # May exceed available CPUs
```

## Code Organization

### Good: Clear Structure

```bash
#!/bin/bash
set -euo pipefail

################################################################################
# Configuration
################################################################################

# ... config variables ...

################################################################################
# Helper Functions
################################################################################

log() { ... }
validate_setup() { ... }

################################################################################
# Step Functions
################################################################################

step1() { ... }
step2() { ... }
step3() { ... }

################################################################################
# Main Pipeline
################################################################################

main() { ... }
```

### Bad: Disorganized Code

```bash
# ❌ Mixed sections, no clear structure
log() { ... }
step1() { ... }
CONFIG_VAR="value"
step2() { ... }
another_function() { ... }
step3() { ... }
main() { ... }
```

## Anti-Patterns to Avoid

### 1. Global State Pollution

```bash
# ❌ Modifies global variables inside functions
step1() {
    RESULT="value"  # Global variable
}

step2() {
    echo ${RESULT}  # Depends on step1 execution order
}
```

### 2. Silent Failures

```bash
# ❌ Ignores errors
command_that_might_fail 2>/dev/null || true
```

### 3. Implicit Dependencies

```bash
# ❌ Depends on side effects
step1() {
    cd output  # Changes directory
}

step2() {
    # Assumes we're still in output directory
    ls
}
```

### 4. Copy-Paste Code

```bash
# ❌ Duplicated code
step1() {
    [[ ! -f "$1" ]] && return 1
    mkdir -p "$(dirname "$2")"
    cp "$1" "$2"
}

step2() {
    [[ ! -f "$1" ]] && return 1  # Same validation
    mkdir -p "$(dirname "$2")"    # Same code
    cp "$1" "$2"
}

# ✅ Extract to function
safe_copy() {
    [[ ! -f "$1" ]] && return 1
    mkdir -p "$(dirname "$2")"
    cp "$1" "$2"
}

step1() { safe_copy "$1" "$2"; }
step2() { safe_copy "$3" "$4"; }
```

## Performance Considerations

### Use Native Tools When Possible

```bash
# ✅ Use native bash for simple operations
while read line; do
    [[ "$line" =~ pattern ]] && echo "$line"
done < file.txt

# ❌ Avoid spawning processes for simple operations
cat file.txt | grep pattern | while read line; do echo "$line"; done
```

### Batch Operations

```bash
# ✅ Batch file operations
find input -name "*.fastq" -exec gzip {} +

# ❌ Individual operations
for f in input/*.fastq; do gzip "$f"; done
```

## Testing Checklist

- [ ] No hardcoded absolute paths
- [ ] All inputs are validated
- [ ] Error handling in place
- [ ] Logging is comprehensive
- [ ] Functions have single responsibility
- [ ] No global state pollution
- [ ] Configuration is centralized
- [ ] Resources are managed properly
- [ ] Code is well-structured and commented

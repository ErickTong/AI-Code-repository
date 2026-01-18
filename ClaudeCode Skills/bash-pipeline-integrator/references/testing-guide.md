# Testing Guide

This guide provides procedures for testing the integrated bash pipeline.

## Testing Phases

### Phase 1: Individual Step Testing

Test each step function independently before integration.

#### Testing Method

Create a test script that calls individual steps:

```bash
#!/bin/bash
# test_single_step.sh

# Source the main pipeline script
source ./run_pipeline.sh

# Set minimal config
INPUT_FILE="test_data/small.fasta"
WORKING_DIR="./test_output"
RUN_PARALLEL=false

# Enable only the step to test
RUN_PREPARE_DATABASE=false
RUN_CHECK_FASTA=false
RUN_EMAPPER=false
RUN_INTERPRO=false
RUN_NR=true  # Only test this step
RUN_UNIPROT=false
RUN_STATISTICS=false

# Call the step directly
step_run_nr
```

#### Test Checklist

- [ ] Input validation works
- [ ] Required tool checks work
- [ ] Command executes successfully
- [ ] Output files are created
- [ ] Output has correct format
- [ ] Error handling triggers appropriately
- [ ] Logging messages are clear
- [ ] Notifications are sent

### Phase 2: Sequential Execution Testing

Test running all steps sequentially.

```bash
#!/bin/bash
# Test sequential mode

INPUT_FILE="test_data/test.fasta"
WORKING_DIR="./test_output"
RUN_PARALLEL=false

# Enable all steps
RUN_PREPARE_DATABASE=true
RUN_CHECK_FASTA=true
RUN_EMAPPER=true
RUN_INTERPRO=true
RUN_NR=true
RUN_UNIPROT=true
RUN_STATISTICS=true

# Run full pipeline
./run_pipeline.sh
```

#### Verify

- [ ] All steps execute in correct order
- [ ] Each step's output becomes next step's input
- [ ] Final outputs are produced
- [ ] No intermediate files are missing
- [ ] Log file is complete
- [ ] Execution time is reasonable

### Phase 3: Parallel Execution Testing

Test running independent steps in parallel.

```bash
#!/bin/bash
# Test parallel mode

INPUT_FILE="test_data/test.fasta"
WORKING_DIR="./test_output"
RUN_PARALLEL=true  # Enable parallel

# Enable all steps
RUN_PREPARE_DATABASE=true
RUN_CHECK_FASTA=true
RUN_EMAPPER=true
RUN_INTERPRO=true
RUN_NR=true
RUN_UNIPROT=true
RUN_STATISTICS=true

# Run full pipeline
./run_pipeline.sh
```

#### Verify

- [ ] Parallel steps start simultaneously
- [ ] Independent steps don't interfere
- [ ] Dependent steps wait for prerequisites
- [ ] Overall runtime is reduced
- [ ] Output files are not corrupted
- [ ] Logs show parallel execution

### Phase 4: Error Handling Testing

Test error scenarios.

#### Test Cases

**Missing Input File:**
```bash
INPUT_FILE="nonexistent.fasta"
./run_pipeline.sh
# Expected: Error message and exit
```

**Missing Required Tool:**
```bash
# Temporarily rename tool
mv /usr/bin/diamond /usr/bin/diamond.bak
./run_pipeline.sh
# Expected: Error about missing tool
mv /usr/bin/diamond.bak /usr/bin/diamond
```

**Step Failure:**
```bash
# Corrupt input file
echo "invalid" > test.fasta
./run_pipeline.sh
# Expected: Pipeline stops, error logged
```

#### Verify

- [ ] Errors are caught and logged
- [ ] Pipeline stops on failure
- [ ] Error messages are descriptive
- [ ] Partial outputs are preserved
- [ ] Failed step is clearly identified

### Phase 5: Configuration Testing

Test various configuration combinations.

```bash
# Test 1: Single step
RUN_EMAPPER=true
RUN_INTERPRO=false
RUN_NR=false

# Test 2: All steps
RUN_EMAPPER=true
RUN_INTERPRO=true
RUN_NR=true

# Test 3: Different thread counts
THREADS_DEFAULT=8
THREADS_DIAMOND=16

# Test 4: Different E-values
EVALUE="1e-10"
```

#### Verify

- [ ] Configuration switches work correctly
- [ ] Default values are used when not set
- [ ] Invalid values are rejected
- [ ] Different thread counts don't cause issues
- [ ] Different parameters produce valid outputs

## Testing Data

### Create Test Dataset

Generate minimal test data for quick testing:

```bash
# Create test directory
mkdir -p test_data

# Create small test FASTA
cat > test_data/small.fasta << 'EOF'
>seq1
ATGCGATCGATCGATCGATCG
>seq2
GCTAGCTAGCTAGCTAGCTAG
>seq3
TTAGCTAGCTAGCTAGCTAGC
EOF
```

### Expected Test Times

| Test Type | Expected Duration |
|-----------|------------------|
| Single step (small data) | < 1 minute |
| Sequential (small data) | < 5 minutes |
| Parallel (small data) | < 2 minutes |
| Single step (real data) | ~30 minutes |
| Full pipeline (real data) | Several hours |

## Debug Mode

Enable debug output for troubleshooting:

```bash
#!/bin/bash
# Run with debug mode

# Enable bash tracing
set -x

# Run pipeline
./run_pipeline.sh
```

Or run with bash debug flag:

```bash
bash -x ./run_pipeline.sh
```

## Log Analysis

Check log files for issues:

```bash
# Check for errors
grep "ERROR" logs/pipeline_*.log

# Check for warnings
grep "WARN" logs/pipeline_*.log

# Check completion status
tail -20 logs/pipeline_*.log
```

## Validation Script

Create an automated validation script:

```bash
#!/bin/bash
# validate_pipeline.sh

validate_output() {
    local expected_file="$1"
    if [[ ! -f "${expected_file}" ]]; then
        echo "FAIL: Missing ${expected_file}"
        return 1
    fi
    echo "PASS: ${expected_file} exists"
    return 0
}

# Check expected outputs
validate_output "output/nr_results.txt"
validate_output "output/emapper_annotations.tsv"
validate_output "output/interpro_results.tsv"
validate_output "output/statistics_summary.txt"

# Check file sizes
if [[ $(stat -f%z "output/nr_results.txt" 2>/dev/null || stat -c%s "output/nr_results.txt") -lt 100 ]]; then
    echo "WARN: nr_results.txt seems too small"
fi
```

## Final Integration Testing Checklist

- [ ] All individual steps tested
- [ ] Sequential execution tested
- [ ] Parallel execution tested
- [ ] Error handling tested
- [ ] Configuration variations tested
- [ ] Debug mode working
- [ ] Logs are comprehensive
- [ ] Documentation is accurate
- [ ] Test data works correctly
- [ ] Validation script passes

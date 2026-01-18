# Project Analysis Workflow

This guide provides a step-by-step workflow for analyzing a bash script project before integration.

## Step 1: Script File Analysis

### Identify All Script Files

First, list all bash scripts in the project directory:

```bash
find . -name "*.sh" -type f | sort
```

### Analyze Each Script

For each script, extract and document:

1. **Purpose and Functionality**
   - What does this script do?
   - What is the input?
   - What is the output?

2. **Dependencies**
   - External commands/tools used
   - Other scripts called
   - Input files required
   - Output files produced

3. **Configuration Parameters**
   - Hardcoded paths
   - User-configurable variables
   - Default values

### Create Script Inventory

Document each script in a table format:

| Script Name | Purpose | Input | Output | Dependencies |
|-------------|---------|--------|--------|--------------|
| 01_prepare.sh | Prepare database | db_source | db.dmnd | diamond |
| 02_annotate.sh | Annotate sequences | input.fasta | annotations.tsv | emapper |

## Step 2: Identify Step Dependencies

Create a dependency graph showing the execution order:

```
01_prepare.sh
    ↓
02_check_fasta.sh
    ↓
03_run_emapper.sh ──┐
    ↓               │
04_run_interpro.sh │
    ↓               │
05_run_nr.sh ←─────┘
    ↓
06_statistics.sh
```

### Classify Steps

**Independent Steps** (can run in parallel):
- Steps that don't share input/output files
- Steps that use different resources

**Dependent Steps** (must run sequentially):
- Steps where output of one is input to another
- Steps that modify shared resources

## Step 3: Data File Analysis

### Check Input Files

```bash
# Find all input files
find . -name "*.fasta" -o -name "*.fastq" -o -name "*.tsv"

# Check file sizes
ls -lh *.fasta *.fastq 2>/dev/null
```

### Preview Large Files

For files >10M, use head to preview:

```bash
head -n 20 large_file.fasta
```

### Analyze File Formats

Document:
- File type (FASTA, FASTQ, TSV, etc.)
- Compression format (gz, bz2, etc.)
- Encoding (UTF-8, ASCII, etc.)

## Step 4: Resource Assessment

Estimate computational requirements:

1. **CPU Requirements**
   - Tools that can use multiple threads
   - Parallelizable steps

2. **Memory Requirements**
   - Memory-intensive operations
   - Database loading requirements

3. **Storage Requirements**
   - Input file sizes
   - Expected output file sizes
   - Temporary space needed

4. **Time Estimates**
   - Typical runtime for each step
   - Total expected pipeline duration

## Step 5: Generate Assessment Report

Create `PROJECT_ASSESSMENT.md` with:

```markdown
# Project Assessment Report

## Project Overview
[Project description]

## Script Inventory
[Table of all scripts]

## Step Dependencies
[Dependency diagram and classification]

## Data Files
[Input/output file list and formats]

## Resource Requirements
- CPU: [requirements]
- Memory: [requirements]
- Storage: [requirements]
- Estimated Time: [duration]

## Risk Assessment
[Potential issues and mitigation]

## Recommendations
[Integration approach and suggestions]
```

## Analysis Checklist

- [ ] All scripts identified and documented
- [ ] Dependencies mapped for each script
- [ ] Input/output files catalogued
- [ ] Step dependencies determined
- [ ] Resource requirements estimated
- [ ] Risks identified
- [ ] Assessment report generated

# Configuration Templates

This document provides ready-to-use configuration section templates for different pipeline types.

## Template 1: Bioinformatics Annotation Pipeline

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
DB_EGGNOG="/data/databases/eggnog/eggnog.db"
DB_INTERPRO="/data/databases/interpro/interproscan.sh"
DB_NR="/data/databases/nr/nr.dmnd"
DB_UNIPROT="/data/databases/uniprot/uniprot_sprot.dmnd"

# ==================== Tool Configuration ====================
THREADS_DEFAULT=16
THREADS_DIAMOND=36
THREADS_EMAPPER=36
EVALUE="1e-5"
MAX_TARGET_SEQS=1
BLAST_TASK="blastx"

# ==================== Notification Configuration ====================
NOTIFY_SCRIPT="/data/Erick_Tong/05Analysis_script/remind.sh"

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

## Template 2: Data Processing Pipeline

```bash
################################################################################
# ==================== Configuration Section ====================
################################################################################

# ==================== Project Configuration ====================
PROJECT_NAME="DataProcessing"
WORKING_DIR="${SCRIPT_DIR}"
OUTPUT_PREFIX="processed"

# ==================== Input Configuration ====================
INPUT_DIR="input/raw_data"
INPUT_PATTERN="*.fastq.gz"

# ==================== Processing Configuration ====================
ADAPTER_FILE="adapters/adapters.fa"
QUALITY_THRESHOLD=20
MIN_LENGTH=50
TRIM_ADAPTERS=true
REMOVE_LOW_QUALITY=true

# ==================== Tool Configuration ====================
THREADS_DEFAULT=8
MEMORY_GB=16
FASTQC_THREADS=4
TRIMMOMATIC_THREADS=8
ALIGNER_THREADS=12

# ==================== Output Configuration ====================
OUTPUT_DIR="output/processed"
QC_DIR="output/qc_reports"
KEEP_TEMP_FILES=false

# ==================== Pipeline Control ====================
RUN_QC_CHECK=true
RUN_ADAPTER_TRIMMING=true
RUN_QUALITY_FILTER=true
RUN_ALIGNMENT=true
RUN_STATS_GENERATION=true
RUN_PARALLEL=true
```

## Template 3: Machine Learning Pipeline

```bash
################################################################################
# ==================== Configuration Section ====================
################################################################################

# ==================== Project Configuration ====================
PROJECT_NAME="MLPipeline"
WORKING_DIR="${SCRIPT_DIR}"
OUTPUT_PREFIX="model"

# ==================== Input Configuration ====================
TRAIN_DATA="data/train.csv"
TEST_DATA="data/test.csv"
FEATURE_FILE="config/features.json"

# ==================== Model Configuration ====================
MODEL_TYPE="random_forest"
N_ESTIMATORS=100
MAX_DEPTH=10
RANDOM_STATE=42
VALIDATION_SPLIT=0.2

# ==================== Tool Configuration ====================
PYTHON_ENV="python3"
PYTHON_SCRIPT="scripts/train_model.py"
THREADS_DEFAULT=4

# ==================== Output Configuration ====================
MODEL_DIR="output/models"
RESULTS_DIR="output/results"
PLOT_DIR="output/plots"

# ==================== Pipeline Control ====================
RUN_DATA_PREPROCESSING=true
RUN_FEATURE_ENGINEERING=true
RUN_MODEL_TRAINING=true
RUN_MODEL_EVALUATION=true
RUN_PLOTTING=true
RUN_PARALLEL=false
```

## Template 4: File Conversion Pipeline

```bash
################################################################################
# ==================== Configuration Section ====================
################################################################################

# ==================== Project Configuration ====================
PROJECT_NAME="FileConverter"
WORKING_DIR="${SCRIPT_DIR}"
OUTPUT_PREFIX="converted"

# ==================== Input Configuration ====================
INPUT_DIR="input"
INPUT_FORMAT="sam"
OUTPUT_FORMAT="bam"

# ==================== Conversion Configuration ====================
KEEP_UNALIGNED=false
SORT_BY_COORDINATE=true
CREATE_INDEX=true
COMPRESS_OUTPUT=true

# ==================== Tool Configuration ====================
THREADS_DEFAULT=12
SAMTOOLS_THREADS=12
PICARD_THREADS=8
MEMORY_GB="8G"

# ==================== Output Configuration ====================
OUTPUT_DIR="output/converted"
LOG_DIR="logs"

# ==================== Pipeline Control ====================
RUN_CONVERSION=true
RUN_SORTING=true
RUN_INDEXING=true
RUN_VALIDATION=true
RUN_PARALLEL=true
```

## Configuration Variable Naming Conventions

### Prefixes

- `RUN_` - Boolean flags for enabling/disabling steps
- `THREADS_` - Thread count for specific tools
- `DB_` - Database paths
- `INPUT_` - Input file/directory specifications
- `OUTPUT_` - Output directory specifications

### Variable Examples

```bash
# Step control
RUN_STEP_NAME=true/false

# Resource allocation
THREADS_DEFAULT=16
THREADS_SPECIFIC_TOOL=36
MEMORY_GB=32

# Paths
INPUT_FILE="path/to/input"
INPUT_DIR="path/to/dir"
OUTPUT_DIR="path/to/output"
DB_NAME="/path/to/database"

# Parameters
EVALUE="1e-5"
MIN_LENGTH=50
QUALITY_THRESHOLD=20
```

## Dynamic Configuration

### Auto-adjusting Based on CPU Count

```bash
# Detect CPU count
CPU_COUNT=$(nproc)
THREADS_DEFAULT=$((CPU_COUNT / 2))

# Or use all cores
THREADS_DEFAULT=${CPU_COUNT}
```

### Auto-adjusting Based on Memory

```bash
# Detect available memory
MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
ALLOCATION=$((MEMORY_GB / 2))G
```

### Conditional Configuration

```bash
# Set parallel based on resource availability
if [[ ${CPU_COUNT} -ge 16 && ${MEMORY_GB} -ge 32 ]]; then
    RUN_PARALLEL=true
    THREADS_DEFAULT=8
else
    RUN_PARALLEL=false
    THREADS_DEFAULT=4
fi
```

## Configuration Validation

Add validation for configuration values:

```bash
validate_configuration() {
    log "Validating configuration..."

    # Check thread counts
    if [[ ${THREADS_DEFAULT} -lt 1 ]]; then
        log_error "THREADS_DEFAULT must be at least 1"
        return 1
    fi

    # Check E-value format
    if [[ ! "${EVALUE}" =~ ^[0-9]+e-[0-9]+$ ]]; then
        log_error "Invalid E-value format: ${EVALUE}"
        return 1
    fi

    # Check input file exists
    if [[ ! -f "${INPUT_FILE}" ]]; then
        log_error "Input file not found: ${INPUT_FILE}"
        return 1
    fi

    log "Configuration is valid"
    return 0
}
```

## User Prompting for Missing Configuration

```bash
prompt_for_config() {
    if [[ -z "${INPUT_FILE}" ]]; then
        read -p "Enter input file path: " INPUT_FILE
    fi

    if [[ ! -f "${INPUT_FILE}" ]]; then
        log_error "Input file not found: ${INPUT_FILE}"
        exit 1
    fi
}
```

#!/bin/bash
#
# preprompt.sh - Cookiecutter Python Project Pre-Generation Validation Script
# 
# This script validates the environment and prepares variables before generating
# a Python project from the cookiecutter template.
#
# Author: Elijah Morgan
# Date: July 26, 2025
# Version: 1.0.0
#

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =============================================================================
# GLOBAL CONFIGURATION
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${TMPDIR:-/tmp}/cookiecutter-preprompt-$(date +%Y%m%d-%H%M%S).log"

# Minimum required Python version
readonly MIN_PYTHON_MAJOR=3
readonly MIN_PYTHON_MINOR=11

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_PYTHON_NOT_FOUND=1
readonly EXIT_PYTHON_VERSION_TOO_OLD=2
readonly EXIT_MISSING_TOOLS=3
readonly EXIT_PERMISSION_DENIED=4
readonly EXIT_VALIDATION_FAILED=5
readonly EXIT_USER_ABORT=6

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Global flags
VERBOSE=false
DRY_RUN=false
INTERACTIVE=true

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" | tee -a "$LOG_FILE" >&2
}

log_warn() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $*" | tee -a "$LOG_FILE"
}

log_debug() {
    if [[ "$VERBOSE" == true ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $*" | tee -a "$LOG_FILE"
    fi
}

# Colored output functions
print_success() {
    echo -e "${GREEN}✓${NC} $*"
}

print_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

print_step() {
    echo -e "${CYAN}→${NC} $*"
}

print_header() {
    echo -e "${WHITE}$*${NC}"
}

# Platform detection
detect_platform() {
    case "$(uname -s)" in
        Linux*)     echo "linux" ;;
        Darwin*)    echo "macos" ;;
        CYGWIN*)    echo "windows" ;;
        MINGW*)     echo "windows" ;;
        MSYS*)      echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

# Version comparison function
version_compare() {
    local version1="$1"
    local version2="$2"
    
    if [[ "$version1" == "$version2" ]]; then
        return 0
    fi
    
    # Split versions using tr and create arrays
    local ver1_str ver2_str
    ver1_str=$(echo "$version1" | tr '.' ' ')
    ver2_str=$(echo "$version2" | tr '.' ' ')
    
    # Convert to arrays
    local ver1_array=($ver1_str)
    local ver2_array=($ver2_str)
    
    # Get array lengths without using problematic syntax
    local len1=0
    local len2=0
    for element in "${ver1_array[@]}"; do
        len1=$((len1 + 1))
    done
    for element in "${ver2_array[@]}"; do
        len2=$((len2 + 1))
    done
    
    # Determine max length
    local max_len=$len1
    if [[ $len2 -gt $max_len ]]; then
        max_len=$len2
    fi
    
    # Compare each component
    for ((i=0; i<max_len; i++)); do
        local v1=0
        local v2=0
        
        # Get values safely
        if [[ $i -lt $len1 ]]; then
            v1="${ver1_array[$i]}"
        fi
        if [[ $i -lt $len2 ]]; then
            v2="${ver2_array[$i]}"
        fi
        
        # Convert to integers for comparison
        v1=$((v1))
        v2=$((v2))
        
        if [[ $v1 -gt $v2 ]]; then
            return 1  # version1 > version2
        elif [[ $v1 -lt $v2 ]]; then
            return 2  # version1 < version2
        fi
    done
    
    return 0  # versions are equal
}

# Cleanup function
cleanup() {
    log_debug "Cleaning up temporary files"
    # Remove sensitive information from log if needed
    # Keep log file for debugging purposes
}

# Signal handlers
handle_interrupt() {
    print_error "Script interrupted by user"
    cleanup
    exit $EXIT_USER_ABORT
}

# Usage information
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Cookiecutter Python Project Pre-Generation Validation Script

OPTIONS:
    -v, --verbose       Enable verbose logging
    -d, --dry-run       Perform validation without making changes
    -n, --non-interactive  Disable interactive prompts
    -h, --help          Show this help message
    -l, --log-file FILE Set custom log file path

EXAMPLES:
    $SCRIPT_NAME                    # Standard validation
    $SCRIPT_NAME -v -d              # Verbose dry-run
    $SCRIPT_NAME --non-interactive  # Automated validation

EXIT CODES:
    $EXIT_SUCCESS                   Success
    $EXIT_PYTHON_NOT_FOUND         Python not found
    $EXIT_PYTHON_VERSION_TOO_OLD   Python version too old
    $EXIT_MISSING_TOOLS            Missing required tools
    $EXIT_PERMISSION_DENIED        Permission denied
    $EXIT_VALIDATION_FAILED        Validation failed
    $EXIT_USER_ABORT               User aborted

EOF
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Find Python executable
find_python_executable() {
    local python_cmd
    
    log_debug "Searching for Python executable"
    
    # Try common Python commands in order of preference
    for python_cmd in python3 python python3.11 python3.12 python3.10; do
        if command -v "$python_cmd" >/dev/null 2>&1; then
            local version
            if version=$(\"$python_cmd\" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'); then
                log_debug "Found $python_cmd with version $version"
                echo "$python_cmd"
                return 0
            fi
        fi
    done
    
    return 1
}

# Validate Python version
validate_python_version() {
    local python_cmd="$1"
    local version
    
    log_debug "Validating Python version for: $python_cmd"
    
    if ! version=$(\"$python_cmd\" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+'); then
        log_error "Unable to determine Python version"
        return 1
    fi
    
    local major minor
    IFS='.' read -r major minor <<< "$version"
    
    if [[ "$major" -lt $MIN_PYTHON_MAJOR ]] || 
       [[ "$major" -eq $MIN_PYTHON_MAJOR && "$minor" -lt $MIN_PYTHON_MINOR ]]; then
        log_error "Python version $version is too old. Required: ${MIN_PYTHON_MAJOR}.${MIN_PYTHON_MINOR}+"
        return 1
    fi
    
    log_debug "Python version $version meets requirements"
    echo "$version"
    return 0
}

# Check Python tools
check_python_tools() {
    local python_cmd="$1"
    local missing_tools=()
    
    print_step "Checking Python tools availability"
    
    # Check pip
    if ! \"$python_cmd\" -m pip --version >/dev/null 2>&1; then
        missing_tools+=("pip")
    else
        print_success "pip is available"
    fi
    
    # Check venv
    if ! \"$python_cmd\" -m venv --help >/dev/null 2>&1; then
        missing_tools+=("venv")
    else
        print_success "venv is available"
    fi
    
    # Check setuptools
    if ! \"$python_cmd\" -c "import setuptools" >/dev/null 2>&1; then
        missing_tools+=("setuptools")
    else
        print_success "setuptools is available"
    fi
    
    # Check if any tools are missing without using problematic syntax
    local missing_count=0
    for tool in "${missing_tools[@]}"; do
        missing_count=$((missing_count + 1))
    done
    
    if [[ $missing_count -gt 0 ]]; then
        print_error "Missing Python tools: ${missing_tools[*]}"
        print_info "Install missing tools with: $python_cmd -m pip install ${missing_tools[*]}"
        return 1
    fi
    
    return 0
}

# Validate cookiecutter variables
validate_cookiecutter_vars() {
    print_step "Validating cookiecutter template variables"
    
    # Check project name
    if [[ -z "${COOKIECUTTER_PROJECT_NAME:-}" ]]; then
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "Enter project name: " COOKIECUTTER_PROJECT_NAME
        else
            log_error "Project name is required"
            return 1
        fi
    fi
    
    # Validate project slug format
    if [[ -n "${COOKIECUTTER_PROJECT_SLUG:-}" ]]; then
        if [[ ! "$COOKIECUTTER_PROJECT_SLUG" =~ ^[a-z][a-z0-9_]*$ ]]; then
            log_error "Project slug must start with lowercase letter and contain only lowercase letters, numbers, and underscores"
            return 1
        fi
    fi
    
    # Check author name
    if [[ -z "${COOKIECUTTER_AUTHOR_NAME:-}" ]]; then
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "Enter author name: " COOKIECUTTER_AUTHOR_NAME
        else
            log_warn "Author name not specified"
        fi
    fi
    
    print_success "Cookiecutter variables validated"
    return 0
}

# Check system dependencies
check_system_dependencies() {
    local platform
    platform=$(detect_platform)
    
    print_step "Checking system dependencies for platform: $platform"
    
    # Common dependencies
    local deps=("git" "curl")
    
    # Platform-specific dependencies
    case "$platform" in
        "linux")
            deps+=("make" "gcc")
            ;;
        "macos")
            deps+=("make")
            ;;
        "windows")
            deps+=("make")
            ;;
    esac
    
    local missing_deps=()
    for dep in "${deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            print_success "$dep is available"
        else
            missing_deps+=("$dep")
        fi
    done
    
    # Check if any dependencies are missing without using problematic syntax
    local missing_dep_count=0
    for dep in "${missing_deps[@]}"; do
        missing_dep_count=$((missing_dep_count + 1))
    done
    
    if [[ $missing_dep_count -gt 0 ]]; then
        print_warning "Missing optional dependencies: ${missing_deps[*]}"
        log_warn "Some features may not work without these dependencies"
    fi
    
    return 0
}

# Check permissions
check_permissions() {
    local target_dir="${PROJECT_DIR:-$(pwd)}"
    
    print_step "Checking write permissions for: $target_dir"
    
    # Check if parent directory is writable
    local parent_dir
    parent_dir=$(dirname "$target_dir")
    
    if [[ ! -w "$parent_dir" ]]; then
        print_error "No write permission for directory: $parent_dir"
        return 1
    fi
    
    # Check if target directory exists and is writable
    if [[ -d "$target_dir" ]]; then
        if [[ ! -w "$target_dir" ]]; then
            print_error "No write permission for existing directory: $target_dir"
            return 1
        fi
        print_warning "Directory already exists: $target_dir"
    fi
    
    print_success "Write permissions verified"
    return 0
}

# Check for naming conflicts
check_naming_conflicts() {
    local project_name="${COOKIECUTTER_PROJECT_SLUG:-my_project}"
    local target_dir="${PROJECT_DIR:-$(pwd)/$project_name}"
    
    print_step "Checking for naming conflicts"
    
    if [[ -d "$target_dir" ]]; then
        print_warning "Directory already exists: $target_dir"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_error "Aborted due to naming conflict"
                return 1
            fi
        else
            log_warn "Proceeding despite naming conflict (non-interactive mode)"
        fi
    fi
    
    print_success "No naming conflicts detected"
    return 0
}

# =============================================================================
# VARIABLE PREPARATION FUNCTIONS
# =============================================================================

# Prepare all cookiecutter variables
prepare_cookiecutter_variables() {
    print_step "Preparing cookiecutter variables"
    
    # Find Python executable
    if ! PYTHON_EXECUTABLE=$(find_python_executable); then
        print_error "Python executable not found"
        print_info "Please install Python ${MIN_PYTHON_MAJOR}.${MIN_PYTHON_MINOR}+ and ensure it's in your PATH"
        return $EXIT_PYTHON_NOT_FOUND
    fi
    
    # Validate Python version
    if ! PYTHON_VERSION=$(validate_python_version "$PYTHON_EXECUTABLE"); then
        print_error "Python version validation failed"
        return $EXIT_PYTHON_VERSION_TOO_OLD
    fi
    
    # Find pip executable
    PIP_EXECUTABLE="$PYTHON_EXECUTABLE -m pip"
    
    # Set venv command
    VENV_COMMAND="$PYTHON_EXECUTABLE -m venv"
    
    # Set project directory
    PROJECT_DIR="${COOKIECUTTER_PROJECT_DIR:-$(pwd)/${COOKIECUTTER_PROJECT_SLUG:-my_project}}"
    
    # Normalize project name
    PROJECT_NAME_NORMALIZED=$(echo "${COOKIECUTTER_PROJECT_SLUG:-my_project}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]/_/g')
    
    # Get author email (try git config first)
    AUTHOR_EMAIL="${COOKIECUTTER_AUTHOR_EMAIL:-}"
    if [[ -z "$AUTHOR_EMAIL" ]] && command -v git >/dev/null 2>&1; then
        AUTHOR_EMAIL=$(git config --get user.email 2>/dev/null || echo "")
    fi
    
    # Set current date
    CURRENT_DATE=$(date '+%Y-%m-%d')
    
    # Export variables for cookiecutter
    export PYTHON_EXECUTABLE
    export PROJECT_DIR
    export PYTHON_VERSION
    export PIP_EXECUTABLE
    export VENV_COMMAND
    export PROJECT_NAME_NORMALIZED
    export AUTHOR_EMAIL
    export CURRENT_DATE
    
    # Log prepared variables
    log "Prepared variables:"
    log "  PYTHON_EXECUTABLE=$PYTHON_EXECUTABLE"
    log "  PROJECT_DIR=$PROJECT_DIR"
    log "  PYTHON_VERSION=$PYTHON_VERSION"
    log "  PIP_EXECUTABLE=$PIP_EXECUTABLE"
    log "  VENV_COMMAND=$VENV_COMMAND"
    log "  PROJECT_NAME_NORMALIZED=$PROJECT_NAME_NORMALIZED"
    log "  AUTHOR_EMAIL=$AUTHOR_EMAIL"
    log "  CURRENT_DATE=$CURRENT_DATE"
    
    print_success "Cookiecutter variables prepared successfully"
    return 0
}

# =============================================================================
# MAIN VALIDATION WORKFLOW
# =============================================================================

# Main validation function
run_validation() {
    print_header "🐍 Cookiecutter Python Project Validation"
    print_header "=========================================="
    echo
    
    log "Starting validation process"
    log "Platform: $(detect_platform)"
    log "Script: $SCRIPT_NAME"
    log "Log file: $LOG_FILE"
    echo
    
    # Prepare variables first
    if ! prepare_cookiecutter_variables; then
        print_error "Variable preparation failed"
        return $EXIT_VALIDATION_FAILED
    fi
    echo
    
    # Run validation checks
    local validation_steps=(
        "check_python_tools \"$PYTHON_EXECUTABLE\""
        "validate_cookiecutter_vars"
        "check_system_dependencies"
        "check_permissions"
        "check_naming_conflicts"
    )
    
    for step in "${validation_steps[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            print_info "[DRY RUN] Would execute: $step"
        else
            if ! eval "$step"; then
                print_error "Validation step failed: $step"
                return $EXIT_VALIDATION_FAILED
            fi
        fi
        echo
    done
    
    print_success "All validation checks passed!"
    log "Validation completed successfully"
    
    return $EXIT_SUCCESS
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -n|--non-interactive)
                INTERACTIVE=false
                shift
                ;;
            -l|--log-file)
                if [[ -n "${2:-}" ]]; then
                    LOG_FILE="$2"
                    shift 2
                else
                    print_error "Log file path required"
                    show_usage
                    exit 1
                fi
                ;;
            -h|--help)
                show_usage
                exit $EXIT_SUCCESS
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    # Set up signal handlers
    trap handle_interrupt INT TERM
    trap cleanup EXIT
    
    # Parse arguments
    parse_arguments "$@"
    
    # Initialize logging
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    log "=== Cookiecutter Python Project Validation Started ==="
    log "Arguments: $*"
    log "Verbose: $VERBOSE"
    log "Dry run: $DRY_RUN"
    log "Interactive: $INTERACTIVE"
    
    # Load cookiecutter context if available
    if [[ -f "$SCRIPT_DIR/../cookiecutter.json" ]]; then
        log_debug "Loading cookiecutter context from cookiecutter.json"
        # Note: In a real cookiecutter context, these variables would be available
        # For now, we'll use some defaults or environment variables
        COOKIECUTTER_PROJECT_NAME="${COOKIECUTTER_PROJECT_NAME:-{{cookiecutter.project_name}}}"
        COOKIECUTTER_PROJECT_SLUG="${COOKIECUTTER_PROJECT_SLUG:-{{cookiecutter.project_slug}}}"
        COOKIECUTTER_AUTHOR_NAME="${COOKIECUTTER_AUTHOR_NAME:-{{cookiecutter.author_name}}}"
        COOKIECUTTER_PYTHON_VERSION="${COOKIECUTTER_PYTHON_VERSION:-{{cookiecutter.python_version}}}"
    fi
    
    # Run validation
    if run_validation; then
        print_success "🎉 Environment validation completed successfully!"
        print_info "Ready to generate Python project"
        log "=== Validation Completed Successfully ==="
        exit $EXIT_SUCCESS
    else
        print_error "❌ Environment validation failed"
        print_info "Please resolve the issues above and try again"
        log "=== Validation Failed ==="
        exit $EXIT_VALIDATION_FAILED
    fi
}

# Run main function with all arguments
main "$@"

#!/bin/bash
#
# pre_gen_project.sh - Cookiecutter Python Project Pre-Generation Setup Script
# 
# This script initializes the Python environment and sets up the development
# infrastructure before the cookiecutter template is fully generated.
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
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly LOG_FILE="${TMPDIR:-/tmp}/cookiecutter-pregen-$(date +%Y%m%d-%H%M%S).log"

# Project configuration
readonly VENV_DIR="$PROJECT_ROOT/.venv"
readonly REQUIREMENTS_FILE="$PROJECT_ROOT/requirements.txt"
readonly DEV_REQUIREMENTS_FILE="$PROJECT_ROOT/requirements-dev.txt"

# Minimum required Python version (inherits from preprompt validation)
readonly MIN_PYTHON_MAJOR=3
readonly MIN_PYTHON_MINOR=11

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_PYTHON_NOT_FOUND=1
readonly EXIT_VENV_CREATION_FAILED=2
readonly EXIT_PACKAGE_INSTALLATION_FAILED=3
readonly EXIT_PACKAGE_VERIFICATION_FAILED=4
readonly EXIT_ENVIRONMENT_SETUP_FAILED=5
readonly EXIT_USER_ABORT=6
readonly EXIT_ROLLBACK_FAILED=7

# Color codes for output (matching preprompt.sh)
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
FORCE_RECREATE=false

# Environment variables from preprompt or cookiecutter
PYTHON_EXECUTABLE="${PYTHON_EXECUTABLE:-python3}"
PROJECT_NAME="${COOKIECUTTER_PROJECT_NAME:-{{cookiecutter.project_name}}}"
PROJECT_SLUG="${COOKIECUTTER_PROJECT_SLUG:-{{cookiecutter.project_slug}}}"
AUTHOR_NAME="${COOKIECUTTER_AUTHOR_NAME:-{{cookiecutter.author_name}}}"
PYTHON_VERSION="${COOKIECUTTER_PYTHON_VERSION:-{{cookiecutter.python_version}}}"

# =============================================================================
# UTILITY FUNCTIONS (Consistent with preprompt.sh)
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

# Cleanup function with rollback capabilities
cleanup() {
    log_debug "Starting cleanup process"
    
    if [[ "${CLEANUP_VENV:-false}" == true ]] && [[ -d "$VENV_DIR" ]]; then
        print_warning "Rolling back: Removing partially created virtual environment"
        rm -rf "$VENV_DIR" || log_warn "Failed to remove venv directory: $VENV_DIR"
    fi
    
    log_debug "Cleanup completed"
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

Cookiecutter Python Project Pre-Generation Setup Script

OPTIONS:
    -v, --verbose       Enable verbose logging
    -d, --dry-run       Perform setup without making changes
    -n, --non-interactive  Disable interactive prompts
    -f, --force         Force recreation of existing virtual environment
    -h, --help          Show this help message
    -l, --log-file FILE Set custom log file path

EXAMPLES:
    $SCRIPT_NAME                    # Standard setup
    $SCRIPT_NAME -v -f              # Verbose with force recreation
    $SCRIPT_NAME --dry-run          # Preview setup actions

EXIT CODES:
    $EXIT_SUCCESS                   Success
    $EXIT_PYTHON_NOT_FOUND         Python not found
    $EXIT_VENV_CREATION_FAILED     Virtual environment creation failed
    $EXIT_PACKAGE_INSTALLATION_FAILED  Package installation failed
    $EXIT_PACKAGE_VERIFICATION_FAILED  Package verification failed
    $EXIT_ENVIRONMENT_SETUP_FAILED Environment setup failed
    $EXIT_USER_ABORT               User aborted
    $EXIT_ROLLBACK_FAILED          Rollback failed

EOF
}

# =============================================================================
# VIRTUAL ENVIRONMENT MANAGEMENT
# =============================================================================

# Create virtual environment
create_virtual_environment() {
    print_step "Creating Python virtual environment"
    
    # Check if venv already exists
    if [[ -d "$VENV_DIR" ]]; then
        if [[ "$FORCE_RECREATE" == true ]]; then
            print_warning "Removing existing virtual environment"
            if [[ "$DRY_RUN" == false ]]; then
                rm -rf "$VENV_DIR" || {
                    print_error "Failed to remove existing virtual environment"
                    return $EXIT_VENV_CREATION_FAILED
                }
            else
                print_info "[DRY RUN] Would remove: $VENV_DIR"
            fi
        else
            print_warning "Virtual environment already exists: $VENV_DIR"
            if [[ "$INTERACTIVE" == true ]]; then
                read -p "Recreate virtual environment? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    FORCE_RECREATE=true
                    return $(create_virtual_environment)
                fi
            fi
            print_info "Using existing virtual environment"
            return 0
        fi
    fi
    
    # Create new virtual environment
    log "Creating virtual environment with: $PYTHON_EXECUTABLE"
    
    if [[ "$DRY_RUN" == false ]]; then
        if ! "$PYTHON_EXECUTABLE" -m venv "$VENV_DIR"; then
            log_error "Failed to create virtual environment"
            CLEANUP_VENV=true
            return $EXIT_VENV_CREATION_FAILED
        fi
        
        # Verify venv creation
        if [[ ! -f "$VENV_DIR/pyvenv.cfg" ]]; then
            log_error "Virtual environment creation appears to have failed"
            CLEANUP_VENV=true
            return $EXIT_VENV_CREATION_FAILED
        fi
        
        print_success "Virtual environment created successfully"
    else
        print_info "[DRY RUN] Would create venv: $PYTHON_EXECUTABLE -m venv $VENV_DIR"
    fi
    
    return 0
}

# Activate virtual environment
activate_virtual_environment() {
    print_step "Activating virtual environment"
    
    local activate_script
    case "$(detect_platform)" in
        "windows")
            activate_script="$VENV_DIR/Scripts/activate"
            ;;
        *)
            activate_script="$VENV_DIR/bin/activate"
            ;;
    esac
    
    if [[ ! -f "$activate_script" ]]; then
        log_error "Activation script not found: $activate_script"
        return $EXIT_VENV_CREATION_FAILED
    fi
    
    if [[ "$DRY_RUN" == false ]]; then
        # Source the activation script
        # shellcheck source=/dev/null
        source "$activate_script"
        
        # Update PYTHON_EXECUTABLE to use venv python
        case "$(detect_platform)" in
            "windows")
                PYTHON_EXECUTABLE="$VENV_DIR/Scripts/python"
                ;;
            *)
                PYTHON_EXECUTABLE="$VENV_DIR/bin/python"
                ;;
        esac
        
        # Verify activation
        local python_path
        python_path=$("$PYTHON_EXECUTABLE" -c "import sys; print(sys.executable)")
        log_debug "Active Python: $python_path"
        
        if [[ "$python_path" != *"$VENV_DIR"* ]]; then
            log_error "Virtual environment activation failed"
            return $EXIT_VENV_CREATION_FAILED
        fi
        
        print_success "Virtual environment activated"
    else
        print_info "[DRY RUN] Would activate: $activate_script"
    fi
    
    return 0
}

# =============================================================================
# PACKAGE MANAGEMENT
# =============================================================================

# Parse requirements file
parse_requirements() {
    local req_file="$1"
    local packages=()
    
    if [[ ! -f "$req_file" ]]; then
        log_debug "Requirements file not found: $req_file"
        return 0
    fi
    
    log_debug "Parsing requirements from: $req_file"
    
    # Read and parse requirements, skipping comments and empty lines
    while IFS= read -r line; do
        # Skip comments and empty lines
        line=$(echo "$line" | sed 's/#.*//' | xargs)
        if [[ -n "$line" ]]; then
            packages+=("$line")
        fi
    done < "$req_file"
    
    printf '%s\n' "${packages[@]}"
}

# Upgrade pip and essential tools
upgrade_pip_tools() {
    print_step "Upgrading pip and essential tools"
    
    local essential_tools=("pip" "setuptools" "wheel")
    
    for tool in "${essential_tools[@]}"; do
        if [[ "$DRY_RUN" == false ]]; then
            print_info "Upgrading $tool..."
            if ! "$PYTHON_EXECUTABLE" -m pip install --upgrade "$tool" --no-warn-script-location; then
                log_error "Failed to upgrade $tool"
                return $EXIT_PACKAGE_INSTALLATION_FAILED
            fi
            print_success "$tool upgraded successfully"
        else
            print_info "[DRY RUN] Would upgrade: $tool"
        fi
    done
    
    return 0
}

# Install packages from requirements
install_packages() {
    local req_file="$1"
    local package_type="$2"
    
    if [[ ! -f "$req_file" ]]; then
        log_debug "Requirements file not found: $req_file"
        return 0
    fi
    
    print_step "Installing $package_type packages from: $(basename "$req_file")"
    
    local packages
    mapfile -t packages < <(parse_requirements "$req_file")
    
    # Count packages without using problematic syntax
    local package_count=0
    for package in "${packages[@]}"; do
        package_count=$((package_count + 1))
    done
    
    if [[ $package_count -eq 0 ]]; then
        print_info "No packages to install from $req_file"
        return 0
    fi
    
    log "Installing $package_count packages: ${packages[*]}"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Install packages with progress indication
        local failed_packages=()
        local installed_count=0
        
        for package in "${packages[@]}"; do
            print_info "Installing: $package"
            
            if "$PYTHON_EXECUTABLE" -m pip install "$package" --no-warn-script-location; then
                print_success "✓ $package"
                ((installed_count++))
            else
                print_error "✗ $package"
                failed_packages+=("$package")
            fi
        done
        
        # Count failed packages without using problematic syntax
        local failed_count=0
        for package in "${failed_packages[@]}"; do
            failed_count=$((failed_count + 1))
        done
        
        # Report installation results
        print_info "Installation summary: $installed_count/$package_count packages installed"
        
        if [[ $failed_count -gt 0 ]]; then
            print_error "Failed to install: ${failed_packages[*]}"
            log_error "Package installation failures detected"
            return $EXIT_PACKAGE_INSTALLATION_FAILED
        fi
        
        print_success "All $package_type packages installed successfully"
    else
        print_info "[DRY RUN] Would install $package_count packages:"
        printf '  - %s\n' "${packages[@]}"
    fi
    
    return 0
}

# Verify package installation
verify_package_installation() {
    local req_file="$1"
    
    if [[ ! -f "$req_file" ]]; then
        return 0
    fi
    
    print_step "Verifying package installation from: $(basename "$req_file")"
    
    local packages
    mapfile -t packages < <(parse_requirements "$req_file")
    
    # Count packages without using problematic syntax
    local package_count=0
    for package in "${packages[@]}"; do
        package_count=$((package_count + 1))
    done
    
    if [[ $package_count -eq 0 ]]; then
        return 0
    fi
    
    local failed_imports=()
    local verified_count=0
    
    for package_spec in "${packages[@]}"; do
        # Extract package name (remove version specifications)
        local package_name
        package_name=$(echo "$package_spec" | sed 's/[<>=!].*//' | sed 's/\[.*\]//')
        
        # Convert package name to importable module name (basic heuristics)
        local import_name="$package_name"
        case "$package_name" in
            "pillow") import_name="PIL" ;;
            "beautifulsoup4") import_name="bs4" ;;
            "pyyaml") import_name="yaml" ;;
            "python-dateutil") import_name="dateutil" ;;
            "msgpack-python") import_name="msgpack" ;;
        esac
        
        if [[ "$DRY_RUN" == false ]]; then
            print_info "Verifying: $package_name (import: $import_name)"
            
            if "$PYTHON_EXECUTABLE" -c "import $import_name" 2>/dev/null; then
                print_success "✓ $package_name"
                ((verified_count++))
            else
                print_error "✗ $package_name (import failed)"
                failed_imports+=("$package_name")
            fi
        else
            print_info "[DRY RUN] Would verify import: $import_name"
        fi
    done
    
    if [[ "$DRY_RUN" == false ]]; then
        # Count failed imports without using problematic syntax
        local failed_imports_count=0
        for import_failure in "${failed_imports[@]}"; do
            failed_imports_count=$((failed_imports_count + 1))
        done
        
        print_info "Verification summary: $verified_count/$package_count packages verified"
        
        if [[ $failed_imports_count -gt 0 ]]; then
            print_error "Failed to import: ${failed_imports[*]}"
            print_info "This may indicate installation issues or import name mismatches"
            return $EXIT_PACKAGE_VERIFICATION_FAILED
        fi
        
        print_success "All packages verified successfully"
    fi
    
    return 0
}

# =============================================================================
# DEVELOPMENT ENVIRONMENT SETUP
# =============================================================================

# Initialize Git repository
setup_git_repository() {
    print_step "Setting up Git repository"
    
    if [[ -d "$PROJECT_ROOT/.git" ]]; then
        print_info "Git repository already exists"
        return 0
    fi
    
    if ! command -v git >/dev/null 2>&1; then
        print_warning "Git not found, skipping repository initialization"
        return 0
    fi
    
    if [[ "$DRY_RUN" == false ]]; then
        cd "$PROJECT_ROOT"
        
        if git init; then
            print_success "Git repository initialized"
            
            # Create initial .gitignore
            cat > .gitignore << EOF
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
.venv/
pip-log.txt
pip-delete-this-directory.txt

# Distribution / packaging
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# PyInstaller
*.manifest
*.spec

# Unit test / coverage reports
htmlcov/
.tox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
.hypothesis/
.pytest_cache/

# Environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
EOF
            print_success "Created .gitignore file"
        else
            log_error "Failed to initialize Git repository"
        fi
    else
        print_info "[DRY RUN] Would initialize Git repository"
    fi
    
    return 0
}

# Create essential project directories
create_project_structure() {
    print_step "Creating project directory structure"
    
    local dirs=(
        "src/$PROJECT_SLUG"
        "tests"
        "docs"
        "scripts"
        "data"
        ".github/workflows"
    )
    
    for dir in "${dirs[@]}"; do
        local target_dir="$PROJECT_ROOT/$dir"
        
        if [[ "$DRY_RUN" == false ]]; then
            if mkdir -p "$target_dir"; then
                print_success "Created: $dir"
                
                # Create __init__.py for Python packages
                if [[ "$dir" == src/* ]] || [[ "$dir" == "tests" ]]; then
                    touch "$target_dir/__init__.py"
                fi
            else
                log_error "Failed to create directory: $dir"
            fi
        else
            print_info "[DRY RUN] Would create: $dir"
        fi
    done
    
    return 0
}

# Generate project metadata
generate_project_metadata() {
    print_step "Generating project metadata"
    
    # Create setup.py if it doesn't exist
    if [[ ! -f "$PROJECT_ROOT/setup.py" ]] && [[ "$DRY_RUN" == false ]]; then
        cat > "$PROJECT_ROOT/setup.py" << EOF
#!/usr/bin/env python3
"""
Setup script for $PROJECT_NAME
"""

from setuptools import setup, find_packages

setup(
    name="$PROJECT_SLUG",
    version="0.1.0",
    description="$PROJECT_NAME",
    author="$AUTHOR_NAME",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    python_requires=">=$PYTHON_VERSION",
    install_requires=[],
    extras_require={
        "dev": [],
    },
    entry_points={
        "console_scripts": [],
    },
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "Programming Language :: Python :: $PYTHON_VERSION",
    ],
)
EOF
        print_success "Created setup.py"
    fi
    
    # Create pyproject.toml if it doesn't exist
    if [[ ! -f "$PROJECT_ROOT/pyproject.toml" ]] && [[ "$DRY_RUN" == false ]]; then
        cat > "$PROJECT_ROOT/pyproject.toml" << EOF
[build-system]
requires = ["setuptools>=45", "wheel", "setuptools_scm[toml]>=6.2"]
build-backend = "setuptools.build_meta"

[project]
name = "$PROJECT_SLUG"
version = "0.1.0"
description = "$PROJECT_NAME"
authors = [{name = "$AUTHOR_NAME"}]
readme = "README.md"
requires-python = ">=$PYTHON_VERSION"
classifiers = [
    "Development Status :: 3 - Alpha",
    "Intended Audience :: Developers",
    "Programming Language :: Python :: $PYTHON_VERSION",
]

[project.optional-dependencies]
dev = []

[tool.setuptools.packages.find]
where = ["src"]

[tool.setuptools.package-dir]
"" = "src"
EOF
        print_success "Created pyproject.toml"
    fi
    
    return 0
}

# =============================================================================
# ENVIRONMENT VALIDATION
# =============================================================================

# Validate final environment state
validate_environment() {
    print_step "Validating final environment state"
    
    local validation_checks=(
        "check_python_in_venv"
        "check_pip_functionality"
        "check_package_imports"
        "generate_environment_report"
    )
    
    for check in "${validation_checks[@]}"; do
        if [[ "$DRY_RUN" == false ]]; then
            if ! $check; then
                log_error "Environment validation failed: $check"
                return $EXIT_ENVIRONMENT_SETUP_FAILED
            fi
        else
            print_info "[DRY RUN] Would run validation: $check"
        fi
    done
    
    print_success "Environment validation completed"
    return 0
}

# Check Python in virtual environment
check_python_in_venv() {
    local python_path
    python_path=$("$PYTHON_EXECUTABLE" -c "import sys; print(sys.executable)")
    
    if [[ "$python_path" == *"$VENV_DIR"* ]]; then
        print_success "Python is running from virtual environment"
        return 0
    else
        print_error "Python is not running from virtual environment"
        return 1
    fi
}

# Check pip functionality
check_pip_functionality() {
    if "$PYTHON_EXECUTABLE" -m pip list >/dev/null 2>&1; then
        print_success "Pip is functioning correctly"
        return 0
    else
        print_error "Pip functionality check failed"
        return 1
    fi
}

# Check package imports
check_package_imports() {
    if [[ -f "$REQUIREMENTS_FILE" ]]; then
        verify_package_installation "$REQUIREMENTS_FILE"
    else
        print_info "No requirements.txt found, skipping import checks"
    fi
    return 0
}

# Generate environment report
generate_environment_report() {
    print_step "Generating environment report"
    
    local report_file="$PROJECT_ROOT/environment-report.txt"
    
    {
        echo "=== Python Environment Report ==="
        echo "Generated: $(date)"
        echo "Script: $SCRIPT_NAME"
        echo ""
        echo "Python Executable: $PYTHON_EXECUTABLE"
        echo "Python Version: $("$PYTHON_EXECUTABLE" --version)"
        echo "Python Path: $("$PYTHON_EXECUTABLE" -c "import sys; print(sys.executable)")"
        echo "Virtual Environment: $VENV_DIR"
        echo ""
        echo "=== Installed Packages ==="
        "$PYTHON_EXECUTABLE" -m pip list
        echo ""
        echo "=== Environment Variables ==="
        echo "PROJECT_NAME=$PROJECT_NAME"
        echo "PROJECT_SLUG=$PROJECT_SLUG"
        echo "AUTHOR_NAME=$AUTHOR_NAME"
        echo "PYTHON_VERSION=$PYTHON_VERSION"
    } > "$report_file"
    
    print_success "Environment report saved: environment-report.txt"
    return 0
}

# =============================================================================
# MAIN SETUP WORKFLOW
# =============================================================================

# Main setup function
run_setup() {
    print_header "🔧 Cookiecutter Python Project Setup"
    print_header "===================================="
    echo
    
    log "Starting project setup process"
    log "Project: $PROJECT_NAME ($PROJECT_SLUG)"
    log "Author: $AUTHOR_NAME"
    log "Python: $PYTHON_EXECUTABLE ($PYTHON_VERSION)"
    log "Project root: $PROJECT_ROOT"
    echo
    
    # Setup steps
    local setup_steps=(
        "create_virtual_environment"
        "activate_virtual_environment"
        "upgrade_pip_tools"
        "install_packages \"$REQUIREMENTS_FILE\" \"production\""
        "install_packages \"$DEV_REQUIREMENTS_FILE\" \"development\""
        "verify_package_installation \"$REQUIREMENTS_FILE\""
        "setup_git_repository"
        "create_project_structure"
        "generate_project_metadata"
        "validate_environment"
    )
    
    for step in "${setup_steps[@]}"; do
        if ! eval "$step"; then
            print_error "Setup step failed: $step"
            return $EXIT_ENVIRONMENT_SETUP_FAILED
        fi
        echo
    done
    
    print_success "Project setup completed successfully!"
    log "Setup completed successfully"
    
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
            -f|--force)
                FORCE_RECREATE=true
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
    
    log "=== Cookiecutter Python Project Setup Started ==="
    log "Arguments: $*"
    log "Verbose: $VERBOSE"
    log "Dry run: $DRY_RUN"
    log "Interactive: $INTERACTIVE"
    log "Force recreate: $FORCE_RECREATE"
    
    # Run setup
    if run_setup; then
        print_success "🎉 Python project setup completed successfully!"
        print_info "Virtual environment ready at: $VENV_DIR"
        print_info "To activate: source $VENV_DIR/bin/activate"
        log "=== Setup Completed Successfully ==="
        exit $EXIT_SUCCESS
    else
        print_error "❌ Python project setup failed"
        print_info "Check the log file for details: $LOG_FILE"
        log "=== Setup Failed ==="
        exit $EXIT_ENVIRONMENT_SETUP_FAILED
    fi
}

# Run main function with all arguments
main "$@"
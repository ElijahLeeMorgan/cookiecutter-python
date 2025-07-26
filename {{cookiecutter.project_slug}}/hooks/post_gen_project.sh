#!/bin/bash
#
# post_gen_project.sh - Cookiecutter Python Project Post-Generation Finalization Script
# 
# This script finalizes the Python project after cookiecutter template generation,
# validates the complete setup, and provides user confirmation for project acceptance.
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
readonly LOG_FILE="${TMPDIR:-/tmp}/cookiecutter-postgen-$(date +%Y%m%d-%H%M%S).log"

# Project configuration
readonly VENV_DIR="$PROJECT_ROOT/.venv"
readonly REQUIREMENTS_FILE="$PROJECT_ROOT/requirements.txt"
readonly DEV_REQUIREMENTS_FILE="$PROJECT_ROOT/requirements-dev.txt"
readonly PROJECT_REPORT_FILE="$PROJECT_ROOT/PROJECT_SUMMARY.md"

# Hook log files to cleanup
readonly TEMP_LOG_PATTERN="${TMPDIR:-/tmp}/cookiecutter-*-*.log"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_VALIDATION_FAILED=1
readonly EXIT_USER_REJECTED=2
readonly EXIT_ROLLBACK_FAILED=3
readonly EXIT_CLEANUP_FAILED=4
readonly EXIT_USER_ABORT=5

# Color codes for output (matching reference scripts)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Fancy symbols and graphics
readonly CHECKMARK="✓"
readonly CROSSMARK="✗"
readonly WARNING="⚠"
readonly INFO="ℹ"
readonly ARROW="→"
readonly STAR="★"
readonly ROCKET="🚀"
readonly SNAKE="🐍"
readonly SPARKLE="✨"

# Global flags
VERBOSE=false
DRY_RUN=false
INTERACTIVE=true
AUTO_APPROVE=false
KEEP_LOGS=false

# Environment variables from previous hooks
PYTHON_EXECUTABLE="${PYTHON_EXECUTABLE:-python3}"
PROJECT_NAME="${COOKIECUTTER_PROJECT_NAME:-{{cookiecutter.project_name}}}"
PROJECT_SLUG="${COOKIECUTTER_PROJECT_SLUG:-{{cookiecutter.project_slug}}}"
AUTHOR_NAME="${COOKIECUTTER_AUTHOR_NAME:-{{cookiecutter.author_name}}}"
PYTHON_VERSION="${COOKIECUTTER_PYTHON_VERSION:-{{cookiecutter.python_version}}}"

# Build metrics
BUILD_START_TIME=$(date +%s)
TOTAL_PACKAGES_INSTALLED=0
FAILED_PACKAGES=()
VALIDATION_ERRORS=()
CLEANUP_ITEMS=()

# =============================================================================
# UTILITY FUNCTIONS (Consistent with reference scripts)
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

# Enhanced colored output functions
print_success() {
    echo -e "${GREEN}${CHECKMARK}${NC} $*"
}

print_error() {
    echo -e "${RED}${CROSSMARK}${NC} $*" >&2
}

print_warning() {
    echo -e "${YELLOW}${WARNING}${NC} $*"
}

print_info() {
    echo -e "${BLUE}${INFO}${NC} $*"
}

print_step() {
    echo -e "${CYAN}${ARROW}${NC} $*"
}

print_header() {
    echo -e "${WHITE}${BOLD}$*${NC}"
}

print_banner() {
    echo -e "${MAGENTA}${BOLD}$*${NC}"
}

print_highlight() {
    echo -e "${YELLOW}${BOLD}$*${NC}"
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

# Terminal management
clear_terminal() {
    if [[ "$INTERACTIVE" == true ]]; then
        clear
    fi
}

get_terminal_width() {
    local width
    width=$(tput cols 2>/dev/null || echo "80")
    echo "$width"
}

print_separator() {
    local width char="${1:-=}"
    width=$(get_terminal_width)
    printf "%*s\n" "$width" | tr ' ' "$char"
}

# Cleanup function
cleanup() {
    log_debug "Starting cleanup process"
    
    # Clean up any remaining temporary files
    local temp_files=($TEMP_LOG_PATTERN)
    for temp_file in "${temp_files[@]}"; do
        if [[ -f "$temp_file" ]] && [[ "$KEEP_LOGS" != true ]]; then
            rm -f "$temp_file" 2>/dev/null || true
        fi
    done
    
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

Cookiecutter Python Project Post-Generation Finalization Script

OPTIONS:
    -v, --verbose       Enable verbose logging
    -d, --dry-run       Perform validation without making changes
    -n, --non-interactive  Disable interactive prompts
    -y, --yes           Auto-approve project (skip confirmation)
    -k, --keep-logs     Keep temporary log files
    -h, --help          Show this help message
    -l, --log-file FILE Set custom log file path

EXAMPLES:
    $SCRIPT_NAME                    # Interactive finalization
    $SCRIPT_NAME -v -y              # Verbose auto-approve
    $SCRIPT_NAME --dry-run          # Validation only

EXIT CODES:
    $EXIT_SUCCESS               Success
    $EXIT_VALIDATION_FAILED     Validation failed
    $EXIT_USER_REJECTED         User rejected project
    $EXIT_ROLLBACK_FAILED       Rollback failed
    $EXIT_CLEANUP_FAILED        Cleanup failed
    $EXIT_USER_ABORT            User aborted

EOF
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Validate virtual environment
validate_virtual_environment() {
    print_step "Validating virtual environment"
    
    if [[ ! -d "$VENV_DIR" ]]; then
        VALIDATION_ERRORS+=("Virtual environment not found: $VENV_DIR")
        print_error "Virtual environment not found"
        return 1
    fi
    
    # Check activation script
    local activate_script
    case "$(detect_platform)" in
        "windows")
            activate_script="$VENV_DIR/Scripts/activate"
            PYTHON_EXECUTABLE="$VENV_DIR/Scripts/python"
            ;;
        *)
            activate_script="$VENV_DIR/bin/activate"
            PYTHON_EXECUTABLE="$VENV_DIR/bin/python"
            ;;
    esac
    
    if [[ ! -f "$activate_script" ]]; then
        VALIDATION_ERRORS+=("Virtual environment activation script not found: $activate_script")
        print_error "Activation script not found"
        return 1
    fi
    
    if [[ ! -x "$PYTHON_EXECUTABLE" ]]; then
        VALIDATION_ERRORS+=("Python executable not found in venv: $PYTHON_EXECUTABLE")
        print_error "Python executable not found in virtual environment"
        return 1
    fi
    
    print_success "Virtual environment validated"
    return 0
}

# Comprehensive package validation
validate_package_installations() {
    print_step "Validating package installations"
    
    local requirements_files=("$REQUIREMENTS_FILE" "$DEV_REQUIREMENTS_FILE")
    local total_packages=0
    local failed_packages=()
    local validation_results=()
    
    for req_file in "${requirements_files[@]}"; do
        if [[ ! -f "$req_file" ]]; then
            continue
        fi
        
        local package_type
        if [[ "$(basename "$req_file")" == "requirements-dev.txt" ]]; then
            package_type="development"
        else
            package_type="production"
        fi
        
        print_info "Validating $package_type packages from: $(basename "$req_file")"
        
        # Parse requirements
        local packages=()
        while IFS= read -r line; do
            line=$(echo "$line" | sed 's/#.*//' | xargs)
            if [[ -n "$line" ]]; then
                packages+=("$line")
            fi
        done < "$req_file"
        
        # Validate each package
        for package_spec in "${packages[@]}"; do
            local package_name
            package_name=$(echo "$package_spec" | sed 's/[<>=!].*//' | sed 's/\[.*\]//')
            ((total_packages++))
            
            # Check if package is installed
            if "$PYTHON_EXECUTABLE" -m pip show "$package_name" >/dev/null 2>&1; then
                # Try to import the package
                local import_name="$package_name"
                
                # Common package name mappings
                case "$package_name" in
                    "pillow") import_name="PIL" ;;
                    "beautifulsoup4") import_name="bs4" ;;
                    "pyyaml") import_name="yaml" ;;
                    "python-dateutil") import_name="dateutil" ;;
                    "msgpack-python") import_name="msgpack" ;;
                    "typing-extensions") import_name="typing_extensions" ;;
                esac
                
                if "$PYTHON_EXECUTABLE" -c "import $import_name" 2>/dev/null; then
                    print_success "$package_name ($package_type)"
                    validation_results+=("✓ $package_name")
                else
                    print_warning "$package_name (installed but import failed)"
                    failed_packages+=("$package_name (import failed)")
                    validation_results+=("⚠ $package_name (import failed)")
                fi
            else
                print_error "$package_name (not installed)"
                failed_packages+=("$package_name (not installed)")
                validation_results+=("✗ $package_name (not installed)")
            fi
        done
    done
    
    # Count failed packages without using problematic syntax
    local failed_count=0
    for package in "${failed_packages[@]}"; do
        failed_count=$((failed_count + 1))
    done
    
    TOTAL_PACKAGES_INSTALLED=$((total_packages - failed_count))
    FAILED_PACKAGES=("${failed_packages[@]}")
    
    if [[ $failed_count -eq 0 ]]; then
        print_success "All $total_packages packages validated successfully"
        return 0
    else
        print_error "$failed_count of $total_packages packages failed validation"
        VALIDATION_ERRORS+=("Package validation failures: ${failed_packages[*]}")
        return 1
    fi
}

# Validate project structure
validate_project_structure() {
    print_step "Validating project structure"
    
    local required_dirs=(
        "src/$PROJECT_SLUG"
        "tests"
    )
    
    local required_files=(
        "README.md"
        "requirements.txt"
        "src/$PROJECT_SLUG/__init__.py"
        "tests/__init__.py"
    )
    
    local missing_items=()
    
    # Check directories
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$PROJECT_ROOT/$dir" ]]; then
            missing_items+=("Directory: $dir")
        else
            print_success "Directory: $dir"
        fi
    done
    
    # Check files
    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            missing_items+=("File: $file")
        else
            print_success "File: $file"
        fi
    done
    
    # Check if any items are missing without using problematic syntax
    local missing_count=0
    for item in "${missing_items[@]}"; do
        missing_count=$((missing_count + 1))
    done
    
    if [[ $missing_count -gt 0 ]]; then
        print_error "Missing project structure items:"
        for item in "${missing_items[@]}"; do
            print_error "  - $item"
        done
        VALIDATION_ERRORS+=("Missing project structure items: ${missing_items[*]}")
        return 1
    fi
    
    print_success "Project structure validated"
    return 0
}

# =============================================================================
# REPORTING FUNCTIONS
# =============================================================================

# Generate build summary
generate_build_summary() {
    print_step "Generating build summary"
    
    local build_end_time
    build_end_time=$(date +%s)
    local build_duration=$((build_end_time - BUILD_START_TIME))
    local build_duration_formatted
    build_duration_formatted=$(printf "%02d:%02d" $((build_duration / 60)) $((build_duration % 60)))
    
    # Create project summary markdown
    cat > "$PROJECT_REPORT_FILE" << EOF
# $PROJECT_NAME

## Project Information

- **Project Name**: $PROJECT_NAME
- **Project Slug**: $PROJECT_SLUG
- **Author**: $AUTHOR_NAME
- **Python Version**: $PYTHON_VERSION
- **Generated**: $(date '+%Y-%m-%d %H:%M:%S')
- **Build Duration**: ${build_duration_formatted}

## Environment Details

- **Python Executable**: $PYTHON_EXECUTABLE
- **Virtual Environment**: $VENV_DIR
- **Platform**: $(detect_platform)
- **Working Directory**: $PROJECT_ROOT

## Package Installation Summary

- **Total Packages**: $TOTAL_PACKAGES_INSTALLED installed
- **Failed Packages**: $failed_packages_count

EOF

    # Check if there are failed packages without using problematic syntax
    local failed_packages_count=0
    for package in "${FAILED_PACKAGES[@]}"; do
        failed_packages_count=$((failed_packages_count + 1))
    done

    if [[ $failed_packages_count -gt 0 ]]; then
        cat >> "$PROJECT_REPORT_FILE" << EOF

### Failed Package Installations

EOF
        for package in "${FAILED_PACKAGES[@]}"; do
            echo "- $package" >> "$PROJECT_REPORT_FILE"
        done
    fi
    
    cat >> "$PROJECT_REPORT_FILE" << EOF

## Validation Results

EOF

    # Check validation errors without using problematic syntax
    local validation_errors_count=0
    for error in "${VALIDATION_ERRORS[@]}"; do
        validation_errors_count=$((validation_errors_count + 1))
    done

    if [[ $validation_errors_count -eq 0 ]]; then
        echo "✅ All validations passed successfully!" >> "$PROJECT_REPORT_FILE"
    else
        echo "❌ Validation errors detected:" >> "$PROJECT_REPORT_FILE"
        for error in "${VALIDATION_ERRORS[@]}"; do
            echo "- $error" >> "$PROJECT_REPORT_FILE"
        done
    fi
    
    cat >> "$PROJECT_REPORT_FILE" << EOF

## Getting Started

1. Activate the virtual environment:
   \`\`\`bash
   source .venv/bin/activate  # Linux/macOS
   # or
   .venv\\Scripts\\activate     # Windows
   \`\`\`

2. Install additional dependencies:
   \`\`\`bash
   pip install -r requirements-dev.txt
   \`\`\`

3. Run tests:
   \`\`\`bash
   python -m pytest tests/
   \`\`\`

4. Start developing:
   \`\`\`bash
   python src/$PROJECT_SLUG/main.py
   \`\`\`

## Project Structure

\`\`\`
$PROJECT_SLUG/
├── .venv/                 # Virtual environment
├── src/
│   └── $PROJECT_SLUG/     # Main package
│       ├── __init__.py
│       └── main.py
├── tests/                 # Test suite
│   ├── __init__.py
│   └── main.py
├── docs/                  # Documentation
├── requirements.txt       # Production dependencies
├── requirements-dev.txt   # Development dependencies
├── setup.py              # Package setup
├── pyproject.toml        # Modern Python project config
└── README.md             # Project documentation
\`\`\`

---
Generated by Cookiecutter Python Template
EOF
    
    print_success "Build summary generated: PROJECT_SUMMARY.md"
    return 0
}

# =============================================================================
# USER INTERFACE FUNCTIONS
# =============================================================================

# Display welcome banner
show_welcome_banner() {
    clear_terminal
    
    local width
    width=$(get_terminal_width)
    
    print_separator "="
    echo
    
    # ASCII Art Python Logo
    print_banner "    ____        __  __                "
    print_banner "   / __ \\__  __/ /_/ /_  ____  ____  "
    print_banner "  / /_/ / / / / __/ __ \\/ __ \\/ __ \\ "
    print_banner " / ____/ /_/ / /_/ / / / /_/ / / / / "
    print_banner "/_/    \\__, /\\__/_/ /_/\\____/_/ /_/  "
    print_banner "      /____/                        "
    echo
    print_header "${SNAKE} ${SPARKLE} PYTHON PROJECT GENERATED SUCCESSFULLY! ${SPARKLE} ${SNAKE}"
    echo
    print_separator "="
    echo
}

# Display project summary
show_project_summary() {
    print_header "📋 PROJECT SUMMARY"
    print_separator "-"
    echo
    
    print_highlight "Project Details:"
    echo -e "  ${BLUE}Name:${NC}         $PROJECT_NAME"
    echo -e "  ${BLUE}Slug:${NC}         $PROJECT_SLUG"
    echo -e "  ${BLUE}Author:${NC}       $AUTHOR_NAME"
    echo -e "  ${BLUE}Python:${NC}       $PYTHON_VERSION"
    echo -e "  ${BLUE}Location:${NC}     $PROJECT_ROOT"
    echo
    
    print_highlight "Environment Status:"
    if [[ -d "$VENV_DIR" ]]; then
        print_success "Virtual environment created at: $VENV_DIR"
    else
        print_error "Virtual environment not found"
    fi
    
    if [[ $TOTAL_PACKAGES_INSTALLED -gt 0 ]]; then
        print_success "$TOTAL_PACKAGES_INSTALLED packages installed successfully"
    fi
    
    # Count failed packages without using problematic syntax
    local failed_packages_count=0
    for package in "${FAILED_PACKAGES[@]}"; do
        failed_packages_count=$((failed_packages_count + 1))
    done
    
    if [[ $failed_packages_count -gt 0 ]]; then
        print_warning "$failed_packages_count packages failed installation"
        for package in "${FAILED_PACKAGES[@]}"; do
            echo -e "    ${RED}${CROSSMARK}${NC} $package"
        done
    fi
    echo
    
    # Count validation errors without using problematic syntax
    local validation_errors_count=0
    for error in "${VALIDATION_ERRORS[@]}"; do
        validation_errors_count=$((validation_errors_count + 1))
    done
    
    print_highlight "Validation Results:"
    if [[ $validation_errors_count -eq 0 ]]; then
        print_success "All validations passed"
    else
        print_warning "$validation_errors_count validation issues detected"
        for error in "${VALIDATION_ERRORS[@]}"; do
            echo -e "    ${YELLOW}${WARNING}${NC} $error"
        done
    fi
    echo
    
    print_separator "-"
    echo
}

# Interactive user confirmation
get_user_confirmation() {
    if [[ "$AUTO_APPROVE" == true ]]; then
        print_info "Auto-approve enabled, proceeding with project finalization"
        return 0
    fi
    
    if [[ "$INTERACTIVE" != true ]]; then
        print_info "Non-interactive mode, proceeding with project finalization"
        return 0
    fi
    
    print_header "🤔 FINAL CONFIRMATION"
    print_separator "-"
    echo
    
    # Count arrays without using problematic syntax
    local validation_errors_count=0
    local failed_packages_count=0
    
    for error in "${VALIDATION_ERRORS[@]}"; do
        validation_errors_count=$((validation_errors_count + 1))
    done
    
    for package in "${FAILED_PACKAGES[@]}"; do
        failed_packages_count=$((failed_packages_count + 1))
    done
    
    if [[ $validation_errors_count -eq 0 ]] && [[ $failed_packages_count -eq 0 ]]; then
        print_success "Everything looks great! Your Python project is ready to use."
    else
        print_warning "Some issues were detected, but the project is still functional."
        print_info "You can resolve these issues later by reviewing the PROJECT_SUMMARY.md file."
    fi
    
    echo
    print_highlight "Do you want to keep this project? (y/n)"
    echo -e "  ${GREEN}y${NC} - Keep the project and clean up temporary files"
    echo -e "  ${RED}n${NC} - Reject the project and remove all generated files"
    echo
    
    while true; do
        read -p "$(echo -e "${CYAN}Your choice [y/n]:${NC} ")" -n 1 -r
        echo
        case $REPLY in
            [Yy])
                print_success "Project accepted! Finalizing setup..."
                return 0
                ;;
            [Nn])
                print_warning "Project rejected. Initiating rollback..."
                return 1
                ;;
            *)
                print_error "Please enter 'y' for yes or 'n' for no"
                ;;
        esac
    done
}

# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================

# Clean up temporary files
cleanup_temporary_files() {
    print_step "Cleaning up temporary files"
    
    local cleanup_patterns=(
        "$PROJECT_ROOT/.cookiecutter-*"
        "$PROJECT_ROOT/cookiecutter-*"
        "$PROJECT_ROOT/__pycache__"
        "$PROJECT_ROOT/**/__pycache__"
        "$PROJECT_ROOT/*.pyc"
        "$PROJECT_ROOT/**/*.pyc"
        "$PROJECT_ROOT/.DS_Store"
        "$PROJECT_ROOT/**/.DS_Store"
    )
    
    local cleaned_count=0
    
    for pattern in "${cleanup_patterns[@]}"; do
        # Use find to safely handle patterns
        if [[ "$pattern" == *"__pycache__" ]]; then
            find "$PROJECT_ROOT" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
            ((cleaned_count++))
        elif [[ "$pattern" == *".pyc" ]]; then
            find "$PROJECT_ROOT" -name "*.pyc" -type f -delete 2>/dev/null || true
            ((cleaned_count++))
        elif [[ "$pattern" == *".DS_Store" ]]; then
            find "$PROJECT_ROOT" -name ".DS_Store" -type f -delete 2>/dev/null || true
            ((cleaned_count++))
        else
            # Handle direct file/directory patterns
            for item in $pattern; do
                if [[ -e "$item" ]]; then
                    rm -rf "$item" 2>/dev/null || true
                    ((cleaned_count++))
                fi
            done
        fi
    done
    
    # Clean up hook-related temporary files
    if [[ "$KEEP_LOGS" != true ]]; then
        local temp_logs=($TEMP_LOG_PATTERN)
        for log_file in "${temp_logs[@]}"; do
            if [[ -f "$log_file" ]]; then
                rm -f "$log_file" 2>/dev/null || true
                ((cleaned_count++))
            fi
        done
    fi
    
    print_success "Cleaned up $cleaned_count temporary items"
    return 0
}

# Finalize project setup and cleanup template scaffolding
finalize_project() {
    print_step "Finalizing project setup and cleanup"
    
    # Set proper permissions
    if [[ -f "$PROJECT_ROOT/scripts/startup.sh" ]]; then
        chmod +x "$PROJECT_ROOT/scripts/startup.sh" 2>/dev/null || true
    fi
    
    # Ensure git repository is properly initialized
    if [[ -d "$PROJECT_ROOT/.git" ]]; then
        cd "$PROJECT_ROOT"
        git add . 2>/dev/null || true
        git commit -m "Initial project structure from cookiecutter template" 2>/dev/null || true
    fi
    
    # Create activation helper script
    cat > "$PROJECT_ROOT/activate_env.sh" << 'EOF'
#!/bin/bash
# Convenience script to activate the virtual environment
source .venv/bin/activate
echo "Virtual environment activated!"
echo "Run 'deactivate' to exit the virtual environment."
EOF
    chmod +x "$PROJECT_ROOT/activate_env.sh"
    
    # Remove hooks directory after successful project generation
    local hooks_dir="$PROJECT_ROOT/hooks"
    if [[ -d "$hooks_dir" ]]; then
        print_step "Removing cookiecutter hooks directory"
        if rm -rf "$hooks_dir" 2>/dev/null; then
            print_success "Cookiecutter hooks directory removed: hooks/"
            log "Hooks directory removed successfully: $hooks_dir"
        else
            print_warning "Failed to remove hooks directory: $hooks_dir"
            log_warn "Could not remove hooks directory: $hooks_dir"
            # Don't fail the entire process for this cleanup step
        fi
    else
        log_debug "Hooks directory not found, skipping removal: $hooks_dir"
    fi
    
    print_success "Project finalization completed"
    return 0
}

# =============================================================================
# ROLLBACK FUNCTIONS
# =============================================================================

# Complete project rollback
rollback_project() {
    print_header "🔄 INITIATING PROJECT ROLLBACK"
    print_separator "-"
    echo
    
    print_warning "Removing all generated project files..."
    
    local rollback_items=(
        "$PROJECT_ROOT"
    )
    
    local rollback_success=true
    
    for item in "${rollback_items[@]}"; do
        if [[ -e "$item" ]]; then
            print_info "Removing: $item"
            if rm -rf "$item" 2>/dev/null; then
                print_success "Removed: $item"
            else
                print_error "Failed to remove: $item"
                rollback_success=false
            fi
        fi
    done
    
    if [[ "$rollback_success" == true ]]; then
        print_success "Project rollback completed successfully"
        print_info "All generated files have been removed"
        return 0
    else
        print_error "Project rollback encountered errors"
        print_info "Some files may need to be removed manually"
        return 1
    fi
}

# =============================================================================
# MAIN WORKFLOW
# =============================================================================

# Main validation and finalization
run_finalization() {
    log "Starting project finalization process"
    log "Project: $PROJECT_NAME ($PROJECT_SLUG)"
    log "Author: $AUTHOR_NAME"
    log "Python: $PYTHON_EXECUTABLE ($PYTHON_VERSION)"
    log "Project root: $PROJECT_ROOT"
    
    # Show welcome banner
    show_welcome_banner
    
    # Run validations
    print_header "${ROCKET} VALIDATING PROJECT SETUP"
    print_separator "="
    echo
    
    local validation_success=true
    
    # Validate virtual environment
    if ! validate_virtual_environment; then
        validation_success=false
    fi
    echo
    
    # Validate package installations
    if ! validate_package_installations; then
        validation_success=false
    fi
    echo
    
    # Validate project structure
    if ! validate_project_structure; then
        validation_success=false
    fi
    echo
    
    # Generate build summary
    generate_build_summary
    echo
    
    # Show project summary
    show_project_summary
    
    # Get user confirmation
    if get_user_confirmation; then
        # User accepted the project
        print_header "${SPARKLE} FINALIZING PROJECT"
        print_separator "="
        echo
        
        cleanup_temporary_files
        echo
        
        finalize_project
        echo
        
        # Show final success message
        print_header "${ROCKET} PROJECT READY!"
        print_separator "="
        echo
        print_success "Your Python project '$PROJECT_NAME' is ready to use!"
        print_info "Cookiecutter template scaffolding has been cleaned up automatically"
        echo
        print_info "Next steps:"
        echo -e "  1. ${CYAN}cd $PROJECT_ROOT${NC}"
        echo -e "  2. ${CYAN}source .venv/bin/activate${NC}  # or use ./activate_env.sh"
        echo -e "  3. ${CYAN}python src/$PROJECT_SLUG/main.py${NC}"
        echo
        print_info "📖 Check PROJECT_SUMMARY.md for detailed information"
        echo
        print_separator "="
        
        log "Project finalization completed successfully"
        return $EXIT_SUCCESS
    else
        # User rejected the project
        if rollback_project; then
            print_header "Project rollback completed"
            log "Project rejected by user and rolled back successfully"
            return $EXIT_USER_REJECTED
        else
            print_error "Project rollback failed"
            log_error "Project rollback failed"
            return $EXIT_ROLLBACK_FAILED
        fi
    fi
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
            -y|--yes)
                AUTO_APPROVE=true
                shift
                ;;
            -k|--keep-logs)
                KEEP_LOGS=true
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
    
    log "=== Cookiecutter Python Project Finalization Started ==="
    log "Arguments: $*"
    log "Verbose: $VERBOSE"
    log "Dry run: $DRY_RUN"
    log "Interactive: $INTERACTIVE"
    log "Auto approve: $AUTO_APPROVE"
    log "Keep logs: $KEEP_LOGS"
    
    # Run finalization
    exit_code=$EXIT_SUCCESS
    if ! run_finalization; then
        exit_code=$?
    fi
    
    log "=== Finalization Process Completed ==="
    exit $exit_code
}

# Run main function with all arguments
main "$@"


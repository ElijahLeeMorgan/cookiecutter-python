# 🐍 Cookiecutter Python Template

[![Python](https://img.shields.io/badge/Python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Cookiecutter](https://img.shields.io/badge/Cookiecutter-Template-orange.svg)](https://github.com/cookiecutter/cookiecutter)
[![Cruft](https://img.shields.io/badge/Cruft-Enabled-purple.svg)](https://cruft.github.io/cruft/)

A **production-ready, enterprise-grade** cookiecutter template for Python projects. This template enforces best practices, provides comprehensive automation, and generates projects that meet the highest industry standards.

## ✨ Features

### 🏗️ **Enterprise Architecture**
- **Standardized Project Structure**: Enforced `src/` layout with proper packaging
- **Comprehensive Testing Framework**: Unit, integration, and e2e testing with pytest
- **Development Tools Integration**: Pre-configured linting, formatting, and type checking
- **Virtual Environment Management**: Automated venv creation and dependency installation
- **Git Integration**: Automatic repository initialization with comprehensive `.gitignore`

### 🔧 **Development Environment**
- **VS Code Dev Container**: Pre-configured with 30+ essential extensions
- **GitHub Codespaces Ready**: Optimized for cloud development
- **Type Safety**: Full mypy integration with strict type checking
- **Code Quality**: Black, isort, pylint, and pre-commit hooks
- **Documentation**: Automated docstring generation and README maintenance

### 🚀 **Automation & Validation**
- **Three-Phase Hook System**: Pre-validation, setup, and post-generation verification
- **Comprehensive Validation**: Python version, dependencies, and environment checks
- **Smart Package Management**: Automatic dependency resolution and verification
- **Interactive Setup**: User-friendly project configuration with rollback capabilities
- **Build Reports**: Detailed generation summaries and troubleshooting guidance

### 📊 **Project Structure**

```
{{cookiecutter.project_slug}}/
├── .devcontainer/           # VS Code dev container configuration
│   └── devcontainer.json   # Container settings with extensions
├── .github/                 # GitHub workflows and templates
│   └── python.prompt.md    # Development guidelines and standards
├── src/                     # 📁 ALL source code goes here
│   └── {{cookiecutter.project_slug}}/
│       ├── __init__.py
│       ├── main.py
│       ├── core/           # Core business logic
│       ├── utils/          # Utility functions
│       └── models/         # Data models and schemas
├── tests/                   # 🧪 ALL tests go here
│   ├── __init__.py
│   ├── main.py
│   ├── unit/               # Unit tests
│   ├── integration/        # Integration tests
│   └── e2e/               # End-to-end tests
├── tools/                   # 🔧 Development utilities
│   ├── __init__.py
│   └── _base.py           # Base tool functionality
├── docs/                    # 📚 Documentation
├── notes/                   # 📝 Project notes and planning
│   └── notes.md
├── scripts/                 # 🔨 Build and utility scripts
│   ├── startup.sh
│   └── update.py
├── hooks/                   # 🪝 Cookiecutter automation hooks
│   ├── preprompt.sh        # Pre-generation validation
│   ├── pre_gen_project.sh  # Environment setup
│   └── post_gen_project.sh # Final validation & cleanup
├── requirements.txt         # Production dependencies
├── requirements-dev.txt     # Development dependencies
├── setup.py                # Package configuration
├── pyproject.toml          # Modern Python project config
├── README.md               # Project documentation
└── LICENSE                 # MIT License
```

## 🚀 Quick Start

### Prerequisites

- Python 3.11 or higher
- [Cookiecutter](https://cookiecutter.readthedocs.io/) or [Cruft](https://cruft.github.io/cruft/)
- Git

### Installation

#### Using Cruft (Recommended)
```bash
# Install cruft
pip install cruft

# Generate new project
cruft create https://github.com/ElijahLeeMorgan/cookiecutter-python.git
```

#### Using Cookiecutter
```bash
# Install cookiecutter
pip install cookiecutter

# Generate new project
cookiecutter https://github.com/ElijahLeeMorgan/cookiecutter-python.git
```

### Template Updates
```bash
# Update existing project from template
cruft update
```

## ⚙️ Configuration Options

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `project_name` | Human-readable project name | "My Awesome Project" | "Data Analysis Toolkit" |
| `project_slug` | Python package name (lowercase, underscores) | "my_awesome_project" | "data_analysis_toolkit" |
| `description` | Brief project description | "A short description..." | "Advanced data processing tools" |
| `author_name` | Project author | "Elijah Morgan" | "Your Name" |
| `python_version` | Target Python version | "3.11" | "3.12" |
| `python_interpreter_path` | Python executable path | `$where("python3")` | "/usr/bin/python3" |

## 🔄 Development Workflow

### 1. **Project Generation**
The template uses a sophisticated three-phase hook system:

#### **Phase 1: Pre-Prompt Validation** (`preprompt.sh`)
- ✅ Validates Python 3.11+ installation
- ✅ Checks essential tools (pip, venv, setuptools)
- ✅ Verifies system dependencies and permissions
- ✅ Prepares cookiecutter variables and environment

#### **Phase 2: Environment Setup** (`pre_gen_project.sh`)
- 🔧 Creates and activates virtual environment
- 📦 Installs production and development dependencies
- 🧪 Verifies package installations with import testing
- 📁 Sets up project structure and Git repository
- 📄 Generates project metadata and configuration files

#### **Phase 3: Final Validation** (`post_gen_project.sh`)
- ✅ Comprehensive project validation
- 📊 Generates detailed build summary report
- 🎨 Presents beautiful welcome interface
- ❓ Interactive user confirmation with rollback capability
- 🧹 Cleanup of temporary files and optimization

### 2. **Development Standards**

The template enforces enterprise-grade development practices:

- **Type Safety**: Full type annotations with mypy validation
- **Code Quality**: Black formatting, isort imports, pylint analysis
- **Testing**: Comprehensive test coverage with pytest
- **Documentation**: Detailed docstrings and README maintenance
- **SOLID Principles**: Object-oriented design patterns
- **Memory Management**: Resource cleanup and optimization
- **Error Handling**: Graceful exception management
- **Logging**: Structured logging with appropriate levels

### 3. **Getting Started with Generated Project**

```bash
# Navigate to your new project
cd your_project_name

# Activate virtual environment
source .venv/bin/activate  # Linux/macOS
# or
.venv\Scripts\activate     # Windows

# Install additional development dependencies
pip install -r requirements-dev.txt

# Run tests
python -m pytest tests/

# Start developing
python src/your_project_name/main.py
```

## 🛠️ Development Tools

### Included VS Code Extensions
- **Python Development**: Python, Pylance, Debugpy
- **Jupyter Support**: Full notebook integration with renderers
- **Code Quality**: ESLint, Prettier, Better Comments
- **Git Integration**: GitHub Copilot, Pull Requests, Remote repositories
- **Data Tools**: Rainbow CSV, Thunder Client, Postman
- **Remote Development**: SSH, Containers, WSL support

### Pre-configured Tools
- **Testing**: pytest with coverage reporting
- **Linting**: pylint, flake8, mypy
- **Formatting**: black, isort, prettier
- **Documentation**: Sphinx-ready structure
- **Git Hooks**: pre-commit framework integration

## 🔍 Troubleshooting

### Common Issues

#### **Python Version Conflicts**
```bash
# Ensure Python 3.11+ is installed
python3 --version

# Update cookiecutter variables if needed
export PYTHON_EXECUTABLE="/usr/bin/python3.11"
```

#### **Permission Errors**
```bash
# Ensure write permissions in target directory
chmod u+w target_directory
```

#### **Package Installation Failures**
- Check virtual environment activation
- Verify internet connectivity
- Review requirements.txt for version conflicts
- Check the generated `environment-report.txt` for details

#### **Template Update Issues**
```bash
# Force update with cruft
cruft update --skip-apply-ask

# Resolve conflicts manually if needed
```

## 📄 License

This template is licensed under the [MIT License](LICENSE). Generated projects inherit this license but can be changed as needed.

## 🙏 Acknowledgments

- Built with [Cookiecutter](https://github.com/cookiecutter/cookiecutter)
- Template updates managed by [Cruft](https://cruft.github.io/cruft/)
- Inspired by Python packaging best practices and enterprise development standards

---

**Ready to create enterprise-grade Python projects?** 🚀

Generate your first project now:
```bash
cruft create https://github.com/ElijahLeeMorgan/cookiecutter-python.git
```

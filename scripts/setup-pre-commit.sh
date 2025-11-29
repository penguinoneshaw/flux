#!/usr/bin/env bash
# Setup pre-commit hooks for the Flux repository
# Run this once to install all dependencies

set -e

echo "Setting up pre-commit hooks for Flux repository..."

# Check Python availability
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is required but not installed"
    echo "Install from: https://www.python.org/"
    exit 1
fi

echo "OK: Python 3 found"

# Install pre-commit framework
echo "Installing pre-commit framework..."
pip install pre-commit

# Install git hooks
echo "Installing git hooks..."
pre-commit install
pre-commit install --hook-type commit-msg

# Check for kubeconform
if ! command -v kubeconform &> /dev/null; then
    echo "WARNING: kubeconform not found. Installing..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        brew install kubeconform
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        curl -L https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz | tar xz
        sudo mv kubeconform /usr/local/bin/
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        # Windows
        echo "WARNING: Windows detected. Please download kubeconform from:"
        echo "    https://github.com/yannh/kubeconform/releases"
        echo "    Extract and add to PATH"
    fi
fi

# Check for prettier
if ! command -v prettier &> /dev/null; then
    echo "WARNING: prettier not found. Installing via npm..."
    npm install --global prettier
fi

# Check for kubectl
if ! command -v kubectl &> /dev/null; then
    echo "WARNING: kubectl not found but required for resource validation"
    echo "Install from: https://kubernetes.io/docs/tasks/tools/"
fi

# Check kubectl connection
if command -v kubectl &> /dev/null; then
    if kubectl cluster-info &> /dev/null; then
        echo "OK: kubectl connected to cluster"
    else
        echo "WARNING: kubectl not connected to cluster (resource validation will be skipped)"
    fi
fi

echo ""
echo "Pre-commit setup complete!"
echo ""
echo "Next steps:"
echo "1. Read the guide: cat PRE_COMMIT_GUIDE.md"
echo "2. Try it out: pre-commit run --all-files"
echo "3. Make a commit: git commit -m 'test commit'"
echo ""
echo "For troubleshooting, see PRE_COMMIT_GUIDE.md"

# Setup pre-commit hooks for the Flux repository (Windows)
# Run with: powershell -ExecutionPolicy Bypass -File scripts\setup-pre-commit.ps1

Write-Host "Setting up pre-commit hooks for Flux repository..." -ForegroundColor Green

# Check Python availability
Write-Host "Checking for Python 3..." -ForegroundColor Cyan
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Python 3 is required but not installed" -ForegroundColor Red
    Write-Host "Install from: https://www.python.org/" -ForegroundColor Yellow
    exit 1
}
Write-Host "OK: Python 3 found" -ForegroundColor Green

# Install pre-commit framework
Write-Host "Installing pre-commit framework..." -ForegroundColor Cyan
pip install pre-commit

# Install git hooks
Write-Host "Installing git hooks..." -ForegroundColor Cyan
pre-commit install
pre-commit install --hook-type commit-msg

# Check for kubeconform
Write-Host "Checking for kubeconform..." -ForegroundColor Cyan
if (-not (Get-Command kubeconform -ErrorAction SilentlyContinue)) {
    Write-Host "WARNING: kubeconform not found" -ForegroundColor Yellow
    Write-Host "Download from: https://github.com/yannh/kubeconform/releases" -ForegroundColor Yellow
    Write-Host "Extract and add to PATH" -ForegroundColor Yellow
}
else {
    Write-Host "OK: kubeconform found" -ForegroundColor Green
}

# Check for prettier
Write-Host "Checking for prettier..." -ForegroundColor Cyan
if (-not (Get-Command prettier -ErrorAction SilentlyContinue)) {
    Write-Host "WARNING: prettier not found. Installing via npm..." -ForegroundColor Yellow
    npm install --global prettier
}
else {
    Write-Host "OK: prettier found" -ForegroundColor Green
}

# Check for kubectl
Write-Host "Checking for kubectl..." -ForegroundColor Cyan
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "WARNING: kubectl not found but required for resource validation" -ForegroundColor Yellow
    Write-Host "Install from: https://kubernetes.io/docs/tasks/tools/" -ForegroundColor Yellow
}
else {
    Write-Host "OK: kubectl found" -ForegroundColor Green
    
    # Check cluster connection
    try {
        kubectl cluster-info | Out-Null
        Write-Host "OK: kubectl connected to cluster" -ForegroundColor Green
    }
    catch {
        Write-Host "WARNING: kubectl not connected to cluster (resource validation will be skipped)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Pre-commit setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Read the guide: Get-Content PRE_COMMIT_GUIDE.md | more"
Write-Host "2. Try it out: pre-commit run --all-files"
Write-Host "3. Make a commit: git commit -m 'test commit'"
Write-Host ""
Write-Host "For troubleshooting, see PRE_COMMIT_GUIDE.md" -ForegroundColor Yellow

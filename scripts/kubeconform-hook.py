#!/usr/bin/env python3
"""
Kubeconform validation hook for pre-commit.
Validates Kubernetes manifests against OpenAPI schemas.

Requires: kubeconform
Install: brew install kubeconform (macOS) or see https://github.com/yannh/kubeconform
"""

import subprocess
import sys
from pathlib import Path


def run_kubeconform(files: list[str]) -> int:
    """
    Run kubeconform on Kubernetes manifest files.
    
    Args:
        files: List of file paths to validate
        
    Returns:
        Exit code (0 = success, 1 = validation failed)
    """
    if not files:
        return 0

    # Filter to only YAML files that might contain K8s manifests
    k8s_files = []
    for file in files:
        # Skip kustomization.yaml files and values.yaml (handled separately)
        if file.endswith(('kustomization.yaml', 'values.yaml')):
            continue
        # Skip files outside Kubernetes directories
        if any(
            part in file.lower()
            for part in ['apps/base', 'apps/x86', 'infrastructure', 'clusters', 'secrets']
        ):
            k8s_files.append(file)

    if not k8s_files:
        return 0

    print(f"Validating {len(k8s_files)} Kubernetes manifest(s) with kubeconform...")

    cmd = [
        'kubeconform',
        '-summary',
        '-output', 'json',
        '-schema-location', 'default',
    ]

    try:
        result = subprocess.run(
            cmd + k8s_files,
            capture_output=True,
            text=True,
            check=False,
        )

        if result.returncode != 0:
            print("Kubeconform validation failed:")
            print(result.stdout)
            if result.stderr:
                print(result.stderr)
            return 1

        print("Kubeconform validation passed")
        return 0

    except FileNotFoundError:
        print(
            "WARNING: kubeconform not found. Install with:\n"
            "  macOS: brew install kubeconform\n"
            "  Linux: https://github.com/yannh/kubeconform/releases\n"
            "  Windows: https://github.com/yannh/kubeconform/releases (add to PATH)"
        )
        return 0  # Don't fail if kubeconform isn't installed


if __name__ == '__main__':
    sys.exit(run_kubeconform(sys.argv[1:]))

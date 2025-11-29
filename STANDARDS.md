# Quick Reference - Standardized Kustomization Format

This document shows the standard format applied to all 15 applications in the repository.

---

## Standard Helm-Based Application Format

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: {app-name}

resources:
  - namespace.yaml
  - repository.yaml
  - release.yaml
  # Optional: other resource files

configMapGenerator:
  - name: {app-name}-values
    namespace: {app-name}
    files:
      - values.yaml
    options:
      disableNameSuffixHash: true

# Optional: configurations for custom kustomize config
configurations:
  - kustomizeconfig.yaml
```

---

## Standard Raw Kubernetes Application Format

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: "{app-name}"

resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  # Other resource files
```

---

## Multi-ConfigMap Format (Complex Apps)

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: {app-name}

resources:
  - namespace.yaml
  - release.yaml
  - auth-config.yaml
  - other-resources.yaml

configMapGenerator:
  - name: {app-name}-main
    namespace: {app-name}
    files:
      - values.yaml
    options:
      disableNameSuffixHash: true
  - name: {app-name}-secondary
    namespace: {app-name}
    files:
      - values.yaml=secondary-values.yaml
    options:
      disableNameSuffixHash: true
  - name: {app-name}-config
    namespace: {app-name}
    files:
      - config.yml
    options:
      disableNameSuffixHash: true
```

---

## Key Points

### ✅ DO

- Always include `apiVersion` and `kind` headers
- Place `namespace:` field at top level
- Group resources logically (namespace first, then other resources)
- Use consistent spacing and indentation
- List resources in logical order: namespace → configuration files → operational resources

### ❌ DON'T

- Omit apiVersion/kind headers
- Use inconsistent namespace declarations
- Use quotes around resource filenames unless necessary
- Mix ordering styles across different files
- Inline Helm values (use ConfigMap instead)

---

## Migration Guide (If Adding New Apps)

### Step 1: Create Directory Structure

```bash
mkdir -p apps/base/{app-name}
cd apps/base/{app-name}
```

### Step 2: Create Files in Order

```bash
# For Helm-based apps:
touch namespace.yaml repository.yaml release.yaml values.yaml kustomization.yaml

# For raw Kubernetes apps:
touch namespace.yaml deployment.yaml service.yaml kustomization.yaml
```

### Step 3: Use Standard Template

Copy the appropriate format from above into your `kustomization.yaml`.

### Step 4: Populate Other Files

- Edit `namespace.yaml` with your app namespace
- Edit `release.yaml` (Helm) or `deployment.yaml` (Kubernetes)
- Edit `values.yaml` with your configuration

### Step 5: Validate

```bash
# Test kustomize build
cd apps/x86
kustomize build . | grep -A 5 {app-name}
```

### Step 6: Reference in Overlay

Edit `apps/x86/kustomization.yaml`:

```yaml
resources:
  - ../base/{app-name}
  # ... other apps
```

---

## Common Mistakes to Avoid

### ❌ Mistake 1: Inconsistent Namespace

```yaml
# WRONG - conflicting namespaces:
namespace: myapp
resources:
  - namespace.yaml
configMapGenerator:
  - name: myapp-values
    namespace: different-namespace  # MISMATCH!

# RIGHT - consistent namespace:
namespace: myapp
resources:
  - namespace.yaml
configMapGenerator:
  - name: myapp-values
    namespace: myapp  # Matches top-level
```

### ❌ Mistake 2: Missing apiVersion/kind

```yaml
# WRONG - will confuse tooling:
resources:
  - namespace.yaml

# RIGHT - explicit declaration:
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
```

### ❌ Mistake 3: Inline Helm Values

```yaml
# WRONG - values in HelmRelease:
spec:
  values:
    replicaCount: 3  # Don't do this!

# RIGHT - values in ConfigMap:
spec:
  valuesFrom:
    - kind: ConfigMap
      name: myapp-values
```

---

## Validation

To verify your application follows the standard:

```bash
# 1. Check YAML syntax
yq e 'true' apps/base/{app-name}/kustomization.yaml

# 2. Check for required fields
grep -E "apiVersion|kind|namespace|resources|configMapGenerator" \
  apps/base/{app-name}/kustomization.yaml

# 3. Validate kustomize build
cd apps/x86
kustomize build . 2>&1 | grep -i error

```

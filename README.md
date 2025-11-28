# Flux GitOps Configuration

A declarative Kubernetes GitOps repository using **Flux CD v2** to manage a self-hosted cluster with 15+ applications (Jellyfin, Immich, Home Assistant, Kanidm, etc.) and infrastructure components (Traefik, MetalLB, PostgreSQL, Prometheus, etc.).

**Key Principle:** Everything is version-controlled and declarative. Flux continuously syncs the cluster to match the repository state.

---

## Quick Start

### Prerequisites

- Kubernetes cluster v1.24+ with Flux v2 bootstrapped
- Git repository with Flux configured
- Tools for local validation:
  - `yq` v4.30+
  - `kustomize` v4.5+
  - `kubeconform` v0.5.0+

### Validate Before Committing

```bash
# Run the validation script to check all manifests before pushing
./scripts/validate.sh
```

This validates:

- YAML syntax correctness
- Kubernetes manifest schema compliance
- Flux custom resources (HelmRelease, Kustomization, etc.)
- Kustomize overlays

---

## Repository Structure

### Three-Tier Architecture

```
.
├── apps/
│   ├── base/              # Application definitions (Helm + Kustomize)
│   └── x86/               # Cluster-specific overlays
├── infrastructure/
│   ├── controllers/       # Operators (Traefik, MetalLB, Cert-Manager, etc.)
│   ├── load-balancer/     # LoadBalancer configuration (MetalLB, KEDA)
│   └── configs/           # Shared configs (ClusterIssuers, Cloudflare data)
├── clusters/x86/          # Flux sync root (bootstraps the cluster)
├── secrets/               # Encrypted secret resources
└── scripts/               # Utility scripts (validation, etc.)
```

### Application Structure (`apps/base/{app-name}/`)

Each application follows this pattern:

| File                 | Purpose                                            |
| -------------------- | -------------------------------------------------- |
| `namespace.yaml`     | Kubernetes Namespace resource                      |
| `repository.yaml`    | Helm chart repository (if Helm-based)              |
| `release.yaml`       | HelmRelease resource (if Helm-based)               |
| `values.yaml`        | Helm values (converted to ConfigMap)               |
| Resource YAMLs       | Raw Kubernetes manifests (if not Helm-based)       |
| `kustomization.yaml` | Kustomize orchestration (references all resources) |
| `*.secret.yaml`      | Encrypted secrets (SOPS + age)                     |

### Overlay Structure (`apps/x86/`)

Cluster-specific customizations using `patchesStrategicMerge`:

- Overrides values for the x86 cluster
- References base resources
- Does **not** duplicate resources

### Infrastructure Synchronization Chain

```yaml
clusters/x86/infrastructure.yaml
├─ infra-load-balancer       (./infrastructure/load-balancer)
├─ infra-controllers         (./infrastructure/controllers)
│  [depends on load-balancer]
└─ infra-configs             (./infrastructure/configs)
   [depends on load-balancer]

clusters/x86/apps.yaml
├─ dependency: infra-configs
└─ apps                      (./apps/x86)
```

---

## Adding a New Application

### Step 1: Create Base Application

```bash
mkdir -p apps/base/{app-name}
cd apps/base/{app-name}
```

### Step 2: Add Resource Files

**For Helm-based apps:**

```bash
# Create files
cat > namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: {app-name}
EOF

cat > repository.yaml << 'EOF'
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: {repo-name}
  namespace: {app-name}
spec:
  interval: 1h
  url: {repo-url}
EOF

cat > release.yaml << 'EOF'
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: {app-name}
  namespace: {app-name}
spec:
  interval: 5m
  chart:
    spec:
      chart: {chart-name}
      sourceRef:
        kind: HelmRepository
        name: {repo-name}
  valuesFrom:
    - kind: ConfigMap
      name: {app-name}-values
EOF

cat > values.yaml << 'EOF'
# Your Helm values here
EOF

cat > kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - repository.yaml
  - release.yaml

configMapGenerator:
  - name: {app-name}-values
    files:
      - values.yaml

generatorOptions:
  disableNameSuffixHash: true
EOF
```

**For raw Kubernetes manifests:**

```bash
# Create files
cat > namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: {app-name}
EOF

# Create app resources (deployment, service, etc.)
cat > deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {app-name}
  namespace: {app-name}
# ... rest of deployment spec
EOF

cat > kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: {app-name}

resources:
  - namespace.yaml
  - deployment.yaml
  # ... other resources
EOF
```

### Step 3: Add Encrypted Secrets (if needed)

```bash
# Edit secret with SOPS
sops apps/base/{app-name}/secret.yaml

# Or encrypt an existing secret:
cat > secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: {app-name}-secret
  namespace: {app-name}
data:
  key: value
EOF

sops -e -i secret.yaml
```

### Step 4: Reference in Cluster Overlay

Edit `apps/x86/kustomization.yaml` and add your app to the resources list:

```yaml
resources:
  - ../base/{app-name}
  # ... other apps
```

### Step 5: Validate and Commit

```bash
./scripts/validate.sh
git add apps/
git commit -m "feat: add {app-name} application"
git push
```

Flux will auto-reconcile within the configured interval (typically 10 minutes).

---

## Modifying Existing Applications

### For Helm-based Apps

1. Edit `apps/base/{app-name}/values.yaml` with new values
2. Run `./scripts/validate.sh` to confirm syntax
3. Commit and push
4. Flux will automatically update the deployment

### For Raw Kubernetes Manifests

1. Edit the resource YAML directly (e.g., `deployment.yaml`)
2. Run `./scripts/validate.sh`
3. Commit and push

### For Cluster-Specific Changes

Use overlays in `apps/x86/` with `patchesStrategicMerge`:

```yaml
# apps/x86/kustomization.yaml
patchesStrategicMerge:
  - {app-name}-values.yaml  # Override base values

resources:
  - ../base/{app-name}
```

Create the patch file:

```yaml
# apps/x86/{app-name}-values.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {app-name}-values
data:
  values.yaml: |
    replicaCount: 1
    # ... cluster-specific values
```

---

## Secrets Management with SOPS + Age

### Encryption Setup

Secrets are encrypted using **SOPS** with **age** encryption. Only `data` and `stringData` fields are encrypted.

**Encryption rules** are defined in `.sops.yaml` (uses age public key).

### Creating Encrypted Secrets

```bash
# Create or edit a secret file with SOPS
sops apps/base/{app-name}/secret.yaml

# SOPS will encrypt automatically on save
```

### Flux Decryption

Both `apps.yaml` and `infrastructure.yaml` include:

```yaml
decryption:
  provider: sops
  secretRef:
    name: sops-age
```

The `sops-age` secret must exist in the `flux-system` namespace:

```bash
kubectl get secret sops-age -n flux-system
```

---

## Validation Reference

### Running Validation Locally

```bash
# Validate all manifests
./scripts/validate.sh
```

### What's Validated

- ✅ YAML syntax correctness (all `.yaml` files)
- ✅ Missing namespaces (warns if namespace field is missing)
- ✅ SOPS secrets structure (warns if encrypted fields are missing)
- ✅ Kubernetes manifest schemas
- ✅ Flux custom resources (HelmRelease, Kustomization, etc.)
- ✅ Kustomize overlays build correctly

### Troubleshooting Validation Errors

| Error                    | Cause                      | Solution                                            |
| ------------------------ | -------------------------- | --------------------------------------------------- |
| `YAML syntax error`      | Invalid YAML formatting    | Use `yq` to check syntax: `yq e 'true' file.yaml`   |
| `Missing namespace`      | Resource lacks namespace   | Add `namespace: {name}` or create `namespace.yaml`  |
| `kubeconform failed`     | Schema mismatch            | Check API version and kind match Kubernetes version |
| `Kustomize build failed` | Invalid kustomization.yaml | Verify resources exist and paths are correct        |

---

## Debugging Flux Sync Issues

### Check Flux Status

```bash
# View Kustomization status
kubectl get kustomization -A

# View HelmRelease status
kubectl get helmrelease -A

# Describe a failed resource
kubectl describe kustomization -n flux-system apps
```

### View Controller Logs

```bash
# Flux Helm controller
kubectl -n flux-system logs deploy/flux-helm-controller -f

# Flux Kustomize controller
kubectl -n flux-system logs deploy/flux-kustomize-controller -f

# Flux Source controller
kubectl -n flux-system logs deploy/flux-source-controller -f
```

### Decryption Issues

```bash
# Verify SOPS age key is in cluster
kubectl get secret sops-age -n flux-system

# Check secret is properly encrypted
sops -d apps/base/{app}/secret.yaml
```

---

## File Organization Reference

| Path                           | Purpose                                             |
| ------------------------------ | --------------------------------------------------- |
| `apps/base/{app}`              | App definitions (Helm + Kustomize)                  |
| `apps/x86`                     | x86 cluster overlay (patches, resource selection)   |
| `infrastructure/controllers`   | Operators: Traefik, MetalLB, Cert-Manager, DB, etc. |
| `infrastructure/load-balancer` | LoadBalancer config (MetalLB, KEDA)                 |
| `infrastructure/configs`       | Shared configs (ClusterIssuers, Cloudflare data)    |
| `clusters/x86`                 | Flux sync root (bootstraps the cluster)             |
| `secrets/`                     | Encrypted secret resources                          |
| `scripts/validate.sh`          | Pre-commit validation tool                          |
| `.sops.yaml`                   | SOPS encryption configuration                       |
| `renovate.json`                | Automated dependency update rules                   |

---

## Automated Dependency Management

The repository uses **Renovate** for automated dependency updates:

**Features:**

- Auto-merges non-major version bumps
- Groups all non-major updates together
- Keeps Helm charts, operators, and base images updated

See `renovate.json` for configuration.

---

## Common Tasks

### Updating a Helm Chart Version

Edit the HelmRepository URL or version in the HelmRelease:

```yaml
# apps/base/{app}/release.yaml
spec:
  chart:
    spec:
      chart: {chart-name}
      version: "1.2.3"  # Specify version here
      sourceRef:
        kind: HelmRepository
        name: {repo-name}
```

### Adding a Persistent Volume Claim

Create a `pvc.yaml` in the app directory:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {app-name}-data
  namespace: {app-name}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path  # or your storage class
  resources:
    requests:
      storage: 10Gi
```

Add to `kustomization.yaml` resources list.

### Debugging a Failed Reconciliation

```bash
# Check the Kustomization/HelmRelease event log
kubectl describe kustomization -n flux-system {app-name}

# View the generated manifests
kubectl get kustomization -n flux-system {app-name} -o yaml

# Manually test kustomize build
cd apps/x86
kustomize build .
```

---

## Contributing

1. Create a feature branch: `git checkout -b feature/add-{app}`
2. Make changes following the patterns above
3. Run validation: `./scripts/validate.sh`
4. Commit with clear messages: `git commit -m "feat: add {description}"`
5. Push and open a pull request

---

## License

This repository is licensed under the Apache License 2.0. See `LICENSE` for details.

# Copilot Instructions for Flux Kubernetes GitOps Configuration

## Project Overview

This is a **Kubernetes GitOps repository** using **Flux CD v2** to declaratively manage a self-hosted Kubernetes cluster. The cluster runs 15+ applications (Jellyfin, Immich, Home Assistant, Kanidm, etc.) with infrastructure components (Traefik, MetalLB, PostgreSQL, etc.) all defined as code.

**Key Principle**: Everything is declarative and version-controlled. Flux continuously syncs the cluster state to match the Git repository state.

## Architecture Pattern

### Three-Tier Structure

1. **`/apps/base`** - Application definitions (Helm releases + Kustomize)
   - Each app folder: `namespace.yaml`, `release.yaml`, `kustomization.yaml`, `values.yaml`
   - Some complex apps: `pvc.yaml`, database configs, secrets, ingress rules
   - Values are stored as ConfigMaps (see `configMapGenerator` in kustomization.yaml)

2. **`/apps/x86`** - Cluster-specific overlays (hardware-specific patches)
   - Pulls from `/apps/base` resources
   - Applies `patchesStrategicMerge` for environment customization
   - Entry point for what actually runs on the x86 cluster

3. **`/infrastructure`** - Cluster infrastructure (load-balancer, controllers, configs)
   - **`/controllers`**: MetalLB, Traefik, Cert-Manager, CloudNative-PG, EMQX, etc.
   - **`/load-balancer`**: MetalLB, KEDA, OIDC roles, binfmt
   - **`/configs`**: Cloudflare data, cluster issuers, shared secrets

### Flux Synchronization Chain

```
clusters/x86/infrastructure.yaml
├─ infra-load-balancer (./infrastructure/load-balancer)
├─ infra-controllers (./infrastructure/controllers) [depends on load-balancer]
├─ infra-configs (./infrastructure/configs) [depends on load-balancer]

clusters/x86/apps.yaml
├─ infra-configs dependency
└─ apps (./apps/x86)
```

Apps install in order; `dependsOn` blocks ensure infrastructure is ready first.

## Critical Patterns & Conventions

### Helm Release Pattern

**Every app with a Helm chart follows this structure**:

```yaml
# release.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
spec:
  valuesFrom:
    - kind: ConfigMap
      name: {app-name}-values
```

**Never** put Helm values directly in release.yaml. Instead:

1. Write values in `values.yaml`
2. Reference via `configMapGenerator` in `kustomization.yaml`
3. HelmRelease pulls from ConfigMap by name

**Examples**: `/apps/base/immich`, `/apps/base/audiobookshelf`, `/infrastructure/controllers/ingress-traefik`

### Raw Kubernetes Manifests Pattern

Apps without Helm charts use plain YAML resources:

- `castsponsorskip`: Single `castsponsorskip.yaml` Deployment
- `home-assistant`: Multiple resources (Deployment, Service, Ingress, ConfigMaps)

Organize as: `namespace.yaml` + resource YAMLs + `kustomization.yaml`

### Secrets Management with SOPS + Age

**Encryption rules** (`.sops.yaml`):

- Only `data` and `stringData` fields are encrypted
- Uses age encryption with public key: `age1hu3ypqyxgvdsjkt2cts6lrn8p0n0gvr4j0xxm5sq22d8ktscg5ysn23mzv`

**Secret files**: ConfigMaps with encrypted data, e.g., `/apps/base/immich/oauth-secret.yaml`

**Flux decryption**: Both `apps.yaml` and `infrastructure.yaml` have:

```yaml
decryption:
  provider: sops
  secretRef:
    name: sops-age
```

### Kustomization Configuration

- **`configurations/kustomizeconfig.yaml`**: Custom Kustomize configs to recognize Flux CRDs
- **`patchesStrategicMerge`**: Override base values per cluster (e.g., `pihole-values.yaml`)
- **No inline patches**: Keep overlays minimal; prefer configMap/secret references

## Development Workflows

### Validation

Run before committing:

```bash
./scripts/validate.sh
```

Validates all YAML syntax and Kubernetes manifests using kubeconform + Flux CRD schemas.

**Prerequisites**:

- `yq v4.30`
- `kustomize v4.5`
- `kubeconform v0.5.0`

### Adding a New Application

1. Create `/apps/base/{app-name}/`
2. Add files (order matters for kustomization):
   - `namespace.yaml`
   - `repository.yaml` (if Helm chart)
   - `release.yaml` (if Helm) OR resource YAMLs
   - `values.yaml` (if Helm)
   - `kustomization.yaml` (references all resources)
3. If secrets needed: Add encrypted YAML files
4. Reference in `/apps/x86/kustomization.yaml` resources list
5. Run `./scripts/validate.sh` to check

**Do NOT**:

- Put Helm values inline in release.yaml
- Reference external images without specifying registries
- Create resources without a namespace

### Modifying Existing Applications

1. Edit `values.yaml` for Helm apps (ConfigMap-managed)
2. Edit resource YAMLs directly for raw Kubernetes manifests
3. For cluster-specific changes: Use `/apps/x86/patchesStrategicMerge`
4. Run validation, commit, push
5. Flux will auto-reconcile within `interval` (typically 10m)

## File Organization Reference

| Path                           | Purpose                                             |
| ------------------------------ | --------------------------------------------------- |
| `apps/base/{app}`              | App definitions (Helm + Kustomize)                  |
| `apps/x86`                     | x86 cluster overlay (patches, resource selection)   |
| `infrastructure/controllers`   | Operators: Traefik, MetalLB, Cert-Manager, DB, etc. |
| `infrastructure/load-balancer` | LoadBalancer config (MetalLB, KEDA)                 |
| `infrastructure/configs`       | Shared configs (ClusterIssuers, Cloudflare data)    |
| `clusters/x86`                 | Flux sync root (bootstrap the whole cluster)        |
| `secrets/`                     | Encrypted secret resources                          |
| `scripts/validate.sh`          | Pre-commit validation tool                          |

## Debugging Flux Sync Issues

- **Flux system logs**: `kubectl -n flux-system logs deploy/flux-helm-controller`
- **Kustomization status**: `kubectl get kustomization -A`
- **HelmRelease status**: `kubectl get helmrelease -A`
- **Decryption issues**: Check SOPS age key is in cluster (`kubectl get secret sops-age -n flux-system`)

## Automated Dependency Management

`renovate.json`:

- Auto-merges non-major version bumps
- Groups all non-major updates together
- Useful for keeping Helm charts, operators, and base images updated

# Gitea wrapper chart

This chart is a thin wrapper that pins the official upstream Gitea chart:

- repository: `https://dl.gitea.com/charts/`
- chart: `gitea`
- version: `12.5.0`

## Dependency workflow

When updating the pinned upstream chart version, refresh dependencies and commit lockfile changes:

```bash
helm dependency update charts/gitea
helm dependency update charts/platform-stack
```

This repository tracks `Chart.lock` files as the source of truth for pinned dependency resolution.

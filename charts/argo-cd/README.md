# argo-cd wrapper chart

This wrapper chart pins the official Argo CD Helm chart and carries the repo's default ingress posture.

Wrapper callers configure the upstream chart through the nested `argocd.*` values block.

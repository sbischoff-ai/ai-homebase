#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def run(cmd: list[str]) -> str:
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def render_bootstrap_values(bootstrap_config: Path) -> str:
    return run(
        [
            "python3",
            str(REPO_ROOT / "scripts" / "bootstrap-config.py"),
            "render-values",
            "--config",
            str(bootstrap_config),
        ]
    )


def render_project(project: str, namespace: str, repo_url: str) -> str:
    return f"""apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: {project}
  namespace: {namespace}
spec:
  sourceRepos:
    - {repo_url}
  destinations:
    - namespace: {namespace}
      server: https://kubernetes.default.svc
    - namespace: kube-system
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
"""


def render_platform_application(
    project: str,
    namespace: str,
    release_name: str,
    repo_url: str,
    repo_branch: str,
    profile: str,
    cluster_name: str,
) -> str:
    return f"""apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {release_name}-platform-stack
  namespace: {namespace}
spec:
  project: {project}
  destination:
    namespace: {namespace}
    server: https://kubernetes.default.svc
  source:
    repoURL: {repo_url}
    targetRevision: {repo_branch}
    path: charts/platform-stack
    helm:
      releaseName: {release_name}
      valueFiles:
        - values-{profile}.yaml
        - clusters/{cluster_name}/bootstrap-values.yaml
        - clusters/{cluster_name}/gitops-values.yaml
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
"""


def render_root_application(
    project: str,
    namespace: str,
    release_name: str,
    repo_url: str,
    repo_branch: str,
    cluster_name: str,
) -> str:
    return f"""apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {release_name}-gitops-root
  namespace: {namespace}
spec:
  project: {project}
  destination:
    namespace: {namespace}
    server: https://kubernetes.default.svc
  source:
    repoURL: {repo_url}
    targetRevision: {repo_branch}
    path: gitops/clusters/{cluster_name}
    directory:
      recurse: true
"""


def render_gitops_agents_md(cluster_name: str, profile: str, namespace: str, release_name: str) -> str:
    render_output = f"/tmp/{release_name}-platform-stack-{profile}.yaml"
    return f"""# AGENTS.md

This repository is the in-cluster source of truth for one bootstrapped ai-homebase cluster.

## First Steps

- Read this file first.
- Keep work inside this repo. Use the files committed here rather than assuming helper scripts or maintainer workflow from some other repo.
- Confirm the active cluster and profile by reading `gitops/clusters/{cluster_name}/applications/platform-stack.yaml`. The current bootstrapped profile is `values-{profile}.yaml`.
- Keep the normal shared-repo posture: branch first, then open a pull request against protected `main`.

## Validation

- For changes that affect Helm render output in `charts/` or in cluster values, validate against the active cluster inputs only:
  - base values: `charts/platform-stack/values.yaml`
  - active profile values: `charts/platform-stack/values-{profile}.yaml`
  - cluster bootstrap values: `charts/platform-stack/clusters/{cluster_name}/bootstrap-values.yaml`
  - cluster GitOps values: `charts/platform-stack/clusters/{cluster_name}/gitops-values.yaml`
- Use `helm dependency update charts/argo-cd`, `helm dependency update charts/gitea`, and `helm dependency update charts/platform-stack` when dependency metadata changed or when Helm reports missing dependencies.
- Lint with raw Helm:
  - `helm lint charts/platform-stack --namespace {namespace} --values charts/platform-stack/values.yaml --values charts/platform-stack/values-{profile}.yaml --values charts/platform-stack/clusters/{cluster_name}/bootstrap-values.yaml --values charts/platform-stack/clusters/{cluster_name}/gitops-values.yaml`
- Render with raw Helm and write output to `/tmp`:
  - `helm template {release_name} charts/platform-stack --namespace {namespace} --values charts/platform-stack/values.yaml --values charts/platform-stack/values-{profile}.yaml --values charts/platform-stack/clusters/{cluster_name}/bootstrap-values.yaml --values charts/platform-stack/clusters/{cluster_name}/gitops-values.yaml > {render_output}`
- For changes limited to `gitops/clusters/{cluster_name}/`, verify referenced source paths and Helm `valueFiles` exist. Rerun the active-profile lint/render commands if the Application source path or `valueFiles` changed.

## Workflow Rules

- Do not change deployment shape without checking the actual Argo CD wiring under `gitops/clusters/{cluster_name}/` and the referenced chart paths.
- Do not publish images from this repo.
- Keep image-build or publish work in the separate `openclaw-sandbox-images` repo unless the task is purely about cluster references.
"""


def render_gitops_values(remote_docker_host: str | None, remote_docker_port: str | None) -> str:
    lines = [
        "argoCd:",
        "  enabled: true",
    ]
    if remote_docker_host and remote_docker_port:
        lines.extend(
            [
                "openclaw:",
                "  remoteDocker:",
                f"    dockerHost: ssh://docker-remote@{remote_docker_host}:{remote_docker_port}",
            ]
        )
    lines.append("")
    return "\n".join(lines)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Render a self-contained GitOps repo snapshot")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--bootstrap-config", type=Path, required=True)
    parser.add_argument("--profile", choices=("k3d", "k3s"), required=True)
    parser.add_argument("--cluster-name", required=True)
    parser.add_argument("--release-name", required=True)
    parser.add_argument("--namespace", required=True)
    parser.add_argument("--repo-url", required=True)
    parser.add_argument("--repo-branch", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--remote-docker-host")
    parser.add_argument("--remote-docker-port")
    return parser


def main() -> int:
    args = build_parser().parse_args()

    if args.output_dir.exists():
        shutil.rmtree(args.output_dir)

    shutil.copytree(REPO_ROOT / "charts", args.output_dir / "charts")
    write_text(
        args.output_dir / "AGENTS.md",
        render_gitops_agents_md(args.cluster_name, args.profile, args.namespace, args.release_name),
    )

    bootstrap_values = render_bootstrap_values(args.bootstrap_config)
    cluster_values_dir = args.output_dir / "charts" / "platform-stack" / "clusters" / args.cluster_name
    write_text(cluster_values_dir / "bootstrap-values.yaml", bootstrap_values)
    write_text(
        cluster_values_dir / "gitops-values.yaml",
        render_gitops_values(args.remote_docker_host, args.remote_docker_port),
    )

    gitops_cluster_dir = args.output_dir / "gitops" / "clusters" / args.cluster_name
    write_text(gitops_cluster_dir / "project.yaml", render_project(args.project, args.namespace, args.repo_url))
    write_text(
        gitops_cluster_dir / "applications" / "platform-stack.yaml",
        render_platform_application(
            args.project,
            args.namespace,
            args.release_name,
            args.repo_url,
            args.repo_branch,
            args.profile,
            args.cluster_name,
        ),
    )
    write_text(
        gitops_cluster_dir / "root-application.yaml",
        render_root_application(
            args.project,
            args.namespace,
            args.release_name,
            args.repo_url,
            args.repo_branch,
            args.cluster_name,
        ),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

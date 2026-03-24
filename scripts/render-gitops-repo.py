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


def render_gitops_values() -> str:
    return """argoCd:
  enabled: true
"""


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
    return parser


def main() -> int:
    args = build_parser().parse_args()

    if args.output_dir.exists():
        shutil.rmtree(args.output_dir)

    shutil.copytree(REPO_ROOT / "charts", args.output_dir / "charts")

    bootstrap_values = render_bootstrap_values(args.bootstrap_config)
    cluster_values_dir = args.output_dir / "charts" / "platform-stack" / "clusters" / args.cluster_name
    write_text(cluster_values_dir / "bootstrap-values.yaml", bootstrap_values)
    write_text(cluster_values_dir / "gitops-values.yaml", render_gitops_values())

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

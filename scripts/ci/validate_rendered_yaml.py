#!/usr/bin/env python3
"""Validate rendered manifest files are parseable YAML and use canonical cert-manager naming."""

from __future__ import annotations

import glob
import re
from pathlib import Path

import yaml

LEGACY_CERT_MANAGER_PATTERN = re.compile(r"certManager[A-Z]")
MIXED_CASE_CERT_MANAGER_PATTERN = re.compile(r"cert(?:-|)manager[A-Z]")


def main() -> None:
    rendered_files = sorted(Path(path) for path in glob.glob("rendered-*.yaml"))
    if not rendered_files:
        raise SystemExit("No rendered manifests found.")

    for filename in rendered_files:
        text = filename.read_text(encoding="utf-8")
        if LEGACY_CERT_MANAGER_PATTERN.search(text):
            raise SystemExit(f"{filename}: found legacy cert-manager alias naming")
        if MIXED_CASE_CERT_MANAGER_PATTERN.search(text):
            raise SystemExit(f"{filename}: found mixed-case cert-manager naming")

        with filename.open("r", encoding="utf-8") as handle:
            documents = list(yaml.safe_load_all(handle))
        print(f"{filename}: parsed {len(documents)} YAML document(s) with canonical cert-manager naming")


if __name__ == "__main__":
    main()

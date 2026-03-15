#!/usr/bin/env python3
"""Validate rendered manifest files are parseable YAML."""

from __future__ import annotations

import glob
from pathlib import Path

import yaml


def main() -> None:
    rendered_files = sorted(Path(path) for path in glob.glob("rendered-*.yaml"))
    if not rendered_files:
        raise SystemExit("No rendered manifests found.")

    for filename in rendered_files:
        with filename.open("r", encoding="utf-8") as handle:
            documents = list(yaml.safe_load_all(handle))
        print(f"{filename}: parsed {len(documents)} YAML document(s)")


if __name__ == "__main__":
    main()

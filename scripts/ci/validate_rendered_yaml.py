#!/usr/bin/env python3
from __future__ import annotations

from glob import glob

import yaml


def main() -> None:
    rendered_files = sorted(glob("rendered-*.yaml"))
    if not rendered_files:
        raise SystemExit("No rendered manifests found.")

    for filename in rendered_files:
        with open(filename, "r", encoding="utf-8") as handle:
            documents = list(yaml.safe_load_all(handle))
        print(f"{filename}: parsed {len(documents)} YAML document(s)")


if __name__ == "__main__":
    main()

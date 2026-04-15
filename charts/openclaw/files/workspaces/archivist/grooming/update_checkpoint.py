#!/usr/bin/env python3
"""Patch the archivist grooming checkpoint JSON atomically."""

from __future__ import annotations

import argparse
import json
import tempfile
from pathlib import Path
from typing import Any


DEFAULT_CHECKPOINT: dict[str, Any] = {
    "version": 1,
    "last_successful_grooming": None,
    "last_successful_graph_link": None,
    "last_weekly_grooming": None,
    "last_triggered_grooming": None,
    "last_run": {
        "run_id": None,
        "trigger": None,
        "scope": None,
        "started_at": None,
        "completed_at": None,
        "status": None,
    },
    "nextcloud": {
        "last_successful_scan": None,
        "surfaces": {},
    },
}


def deep_merge(base: dict[str, Any], patch: dict[str, Any]) -> dict[str, Any]:
    merged = dict(base)
    for key, value in patch.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def parse_value(raw: str) -> Any:
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def set_dotted(target: dict[str, Any], dotted: str, value: Any) -> None:
    parts = dotted.split(".")
    if not parts or any(not part for part in parts):
        raise SystemExit(f"Invalid dotted path: {dotted}")
    cursor = target
    for part in parts[:-1]:
        existing = cursor.setdefault(part, {})
        if not isinstance(existing, dict):
            raise SystemExit(f"Cannot set child key under non-object path: {part}")
        cursor = existing
    cursor[parts[-1]] = value


def load_checkpoint(path: Path) -> dict[str, Any]:
    if not path.exists():
        return dict(DEFAULT_CHECKPOINT)
    loaded = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(loaded, dict):
        raise SystemExit(f"Checkpoint is not a JSON object: {path}")
    return deep_merge(DEFAULT_CHECKPOINT, loaded)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", default="state/grooming-checkpoint.json", help="Checkpoint path.")
    parser.add_argument("--patch-json", default="", help="JSON object to deep-merge into the checkpoint.")
    parser.add_argument("--set", action="append", default=[], metavar="PATH=VALUE", help="Set dotted path to JSON VALUE or string. May be repeated.")
    parser.add_argument("--dry-run", action="store_true", help="Print the resulting checkpoint without writing.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    path = Path(args.file)
    checkpoint = load_checkpoint(path)
    if args.patch_json:
        patch = json.loads(args.patch_json)
        if not isinstance(patch, dict):
            raise SystemExit("--patch-json must be a JSON object")
        checkpoint = deep_merge(checkpoint, patch)
    for item in args.set:
        if "=" not in item:
            raise SystemExit("--set expects PATH=VALUE")
        key, raw_value = item.split("=", 1)
        set_dotted(checkpoint, key, parse_value(raw_value))

    text = json.dumps(checkpoint, indent=2, sort_keys=False) + "\n"
    if args.dry_run:
        print(text, end="")
        return

    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=str(path.parent), delete=False) as handle:
        handle.write(text)
        temp_path = Path(handle.name)
    temp_path.replace(path)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Render or run an archivist Cypher helper with JSON parameters."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


PARAM_RE = re.compile(r"\$([A-Za-z_][A-Za-z0-9_]*)")


def cypher_literal(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        escaped = value.replace("\\", "\\\\").replace("'", "\\'")
        return f"'{escaped}'"
    if isinstance(value, list):
        return "[" + ", ".join(cypher_literal(item) for item in value) + "]"
    if isinstance(value, dict):
        items = []
        for key, item in value.items():
            if not isinstance(key, str):
                raise SystemExit("Cypher map parameter keys must be strings")
            safe_key = key if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", key) else f"`{key.replace('`', '``')}`"
            items.append(f"{safe_key}: {cypher_literal(item)}")
        return "{" + ", ".join(items) + "}"
    raise SystemExit(f"Unsupported parameter type for Cypher literal: {type(value).__name__}")


def read_params(args: argparse.Namespace) -> dict[str, Any]:
    merged: dict[str, Any] = {}
    if args.params:
        raw = Path(args.params).read_text(encoding="utf-8")
        loaded = json.loads(raw)
        if not isinstance(loaded, dict):
            raise SystemExit("--params must point to a JSON object")
        merged.update(loaded)
    if args.params_json:
        loaded = json.loads(args.params_json)
        if not isinstance(loaded, dict):
            raise SystemExit("--params-json must be a JSON object")
        merged.update(loaded)
    return merged


def render_query(template: str, params: dict[str, Any], strict: bool) -> str:
    names = set(PARAM_RE.findall(template))
    missing = sorted(name for name in names if name not in params)
    if missing and strict:
        raise SystemExit(f"Missing required parameter(s): {', '.join(missing)}")
    if missing:
        print(f"Defaulting missing parameter(s) to null: {', '.join(missing)}", file=sys.stderr)
        params = {**params, **{name: None for name in missing}}
    return PARAM_RE.sub(lambda match: cypher_literal(params[match.group(1)]), template)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("query", help="Path to a .cypher helper.")
    parser.add_argument("--params", default="", help="JSON file containing query parameters.")
    parser.add_argument("--params-json", default="", help="Inline JSON object merged after --params.")
    parser.add_argument("--host", default=os.environ.get("MEMGRAPH_HOST", "127.0.0.1"))
    parser.add_argument("--port", default=os.environ.get("MEMGRAPH_PORT", "7687"))
    parser.add_argument("--output-format", default="csv")
    parser.add_argument("--strict", action="store_true", help="Fail if any $param is missing.")
    parser.add_argument("--dry-run", action="store_true", help="Print rendered Cypher instead of running mgconsole.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    template = Path(args.query).read_text(encoding="utf-8")
    rendered = render_query(template, read_params(args), args.strict)
    if args.dry_run:
        sys.stdout.write(rendered)
        if rendered and not rendered.endswith("\n"):
            sys.stdout.write("\n")
        return

    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".cypher", delete=False) as handle:
        handle.write(rendered)
        temp_path = handle.name
    try:
        with open(temp_path, "r", encoding="utf-8") as stdin:
            subprocess.run(
                [
                    "mgconsole",
                    "--host",
                    args.host,
                    "--port",
                    str(args.port),
                    "--output-format",
                    args.output_format,
                ],
                stdin=stdin,
                check=True,
            )
    finally:
        Path(temp_path).unlink(missing_ok=True)


if __name__ == "__main__":
    main()

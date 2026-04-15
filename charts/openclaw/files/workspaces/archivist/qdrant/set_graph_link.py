#!/usr/bin/env python3
"""Annotate selected Qdrant points with graph-link payload metadata."""

from __future__ import annotations

import argparse
import json
from typing import Any

from _qdrant_common import add_common_args, read_json_arg, qdrant_request, require_qdrant_url, utc_now_iso


def build_graph_payload(args: argparse.Namespace) -> dict[str, Any]:
    linked_entity_slugs = list(dict.fromkeys(args.entity_slug or []))
    derived_from = list(dict.fromkeys(args.supersedes or []))
    graph: dict[str, Any] = {
        "status": args.status,
        "linked_at": args.linked_at or utc_now_iso(),
        "memory_slug": args.memory_slug,
        "linked_entity_slugs": linked_entity_slugs,
    }
    if derived_from:
        graph["supersedes_memory_slugs"] = derived_from
    extra = read_json_arg(args.extra, {})
    if not isinstance(extra, dict):
        raise SystemExit("--extra must be a JSON object")
    graph.update(extra)
    return graph


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    add_common_args(parser)
    parser.add_argument("--point-id", action="append", required=True, help="Qdrant point ID to annotate. May be repeated.")
    parser.add_argument("--memory-slug", default="", help="Memgraph MemoryEntry slug. Defaults to qdrant:<point_id> for a single point.")
    parser.add_argument("--entity-slug", action="append", default=[], help="Linked Memgraph entity slug. May be repeated.")
    parser.add_argument("--supersedes", action="append", default=[], help="Older Memgraph memory slug superseded by this memory. May be repeated.")
    parser.add_argument("--status", default="linked", choices=["candidate", "linked", "partial", "skipped"], help="Graph-link status.")
    parser.add_argument("--linked-at", default="", help="ISO-8601 timestamp. Defaults to current UTC time.")
    parser.add_argument("--extra", default="", help="Optional JSON object merged into the graph payload.")
    parser.add_argument("--dry-run", action="store_true", help="Print the Qdrant set-payload request without sending it.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    point_ids = list(dict.fromkeys(args.point_id))
    if len(point_ids) == 1 and not args.memory_slug:
        args.memory_slug = f"qdrant:{point_ids[0]}"
    if not args.memory_slug:
        raise SystemExit("--memory-slug is required when annotating multiple points")

    graph = build_graph_payload(args)
    body = {
        "payload": {"graph": graph},
        "points": point_ids,
    }
    if args.dry_run:
        print(json.dumps(body, sort_keys=True, ensure_ascii=False))
        return

    qdrant_url = require_qdrant_url(args.qdrant_url)
    qdrant_request(
        qdrant_url,
        "POST",
        f"/collections/{args.collection}/points/payload",
        body,
        args.api_key,
    )
    print(json.dumps({"updated_point_ids": point_ids, "graph": graph}, sort_keys=True, ensure_ascii=False))


if __name__ == "__main__":
    main()

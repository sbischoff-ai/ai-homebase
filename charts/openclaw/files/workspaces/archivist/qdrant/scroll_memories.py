#!/usr/bin/env python3
"""Scroll Qdrant memories into normalized JSONL packets for graph grooming."""

from __future__ import annotations

import argparse
from typing import Any

from _qdrant_common import add_common_args, build_filter, normalize_point, qdrant_request, require_qdrant_url, write_jsonl


def scroll_memories(
    *,
    qdrant_url: str,
    collection: str,
    api_key: str,
    query_filter: dict[str, Any] | None,
    limit: int,
    page_size: int,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    offset: Any = None

    while len(rows) < limit:
        request_limit = min(page_size, limit - len(rows))
        body: dict[str, Any] = {
            "limit": request_limit,
            "with_payload": True,
            "with_vector": False,
        }
        if query_filter:
            body["filter"] = query_filter
        if offset is not None:
            body["offset"] = offset

        response = qdrant_request(
            qdrant_url,
            "POST",
            f"/collections/{collection}/points/scroll",
            body,
            api_key,
            missing_collection_ok=True,
        )
        result = response.get("result") or {}
        points = result.get("points") or []
        if not points:
            break
        rows.extend(normalize_point(point) for point in points)
        offset = result.get("next_page_offset")
        if offset is None:
            break

    return rows


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    add_common_args(parser)
    parser.add_argument("--since", default="", help="Alias for --created-gte.")
    parser.add_argument("--created-gte", default="", help="Filter metadata.created greater than or equal to this ISO-8601 timestamp.")
    parser.add_argument("--created-lte", default="", help="Filter metadata.created less than or equal to this ISO-8601 timestamp.")
    parser.add_argument("--project", default="", help="Filter metadata.project.")
    parser.add_argument("--kind", default="", help="Filter metadata.kind.")
    parser.add_argument("--domain", default="", help="Filter metadata.domain.")
    parser.add_argument("--agent", default="", help="Filter metadata.agent.")
    parser.add_argument("--tag", action="append", default=[], help="Filter metadata.tags. May be repeated.")
    parser.add_argument("--graph-status", default="", help="Filter graph.status when rechecking annotated points.")
    parser.add_argument("--limit", type=int, default=100, help="Maximum normalized rows to emit.")
    parser.add_argument("--page-size", type=int, default=64, help="Qdrant scroll page size.")
    parser.add_argument("--out", default="", help="Write JSONL output to this path. Defaults to stdout.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.limit < 1:
        raise SystemExit("--limit must be at least 1")
    if args.page_size < 1:
        raise SystemExit("--page-size must be at least 1")

    qdrant_url = require_qdrant_url(args.qdrant_url)
    created_gte = args.created_gte or args.since
    query_filter = build_filter(
        created_gte=created_gte,
        created_lte=args.created_lte,
        project=args.project,
        kind=args.kind,
        domain=args.domain,
        agent=args.agent,
        tags=args.tag,
        graph_status=args.graph_status,
    )
    rows = scroll_memories(
        qdrant_url=qdrant_url,
        collection=args.collection,
        api_key=args.api_key,
        query_filter=query_filter,
        limit=args.limit,
        page_size=args.page_size,
    )
    write_jsonl(rows, args.out)


if __name__ == "__main__":
    main()

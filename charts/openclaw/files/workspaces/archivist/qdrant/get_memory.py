#!/usr/bin/env python3
"""Fetch one Qdrant memory point by ID and print the normalized packet."""

from __future__ import annotations

import argparse
import json

from _qdrant_common import add_common_args, normalize_point, qdrant_request, require_qdrant_url


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    add_common_args(parser)
    parser.add_argument("point_id", help="Qdrant point ID.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    qdrant_url = require_qdrant_url(args.qdrant_url)
    response = qdrant_request(
        qdrant_url,
        "POST",
        f"/collections/{args.collection}/points",
        {"ids": [args.point_id], "with_payload": True, "with_vector": False},
        args.api_key,
    )
    points = response.get("result") or []
    if not points:
        raise SystemExit(f"Qdrant point not found: {args.point_id}")
    packet = normalize_point(points[0])
    print(json.dumps(packet, sort_keys=True, ensure_ascii=False))


if __name__ == "__main__":
    main()

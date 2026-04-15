#!/usr/bin/env python3
"""Shared helpers for archivist Qdrant grooming scripts."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_COLLECTION = "openclaw-memory"


def add_common_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--qdrant-url",
        default=os.environ.get("QDRANT_URL", ""),
        help="Qdrant base URL. Defaults to QDRANT_URL.",
    )
    parser.add_argument(
        "--collection",
        default=os.environ.get("QDRANT_COLLECTION", DEFAULT_COLLECTION),
        help=f"Qdrant collection name. Defaults to QDRANT_COLLECTION or {DEFAULT_COLLECTION}.",
    )
    parser.add_argument(
        "--api-key",
        default=os.environ.get("QDRANT_API_KEY", ""),
        help="Optional Qdrant API key. Defaults to QDRANT_API_KEY.",
    )


def require_qdrant_url(raw_url: str) -> str:
    url = raw_url.rstrip("/")
    if not url:
        raise SystemExit("QDRANT_URL is required. Set QDRANT_URL or pass --qdrant-url.")
    return url


def qdrant_request(
    qdrant_url: str,
    method: str,
    path: str,
    body: dict[str, Any] | None,
    api_key: str = "",
) -> dict[str, Any]:
    data = None if body is None else json.dumps(body, sort_keys=True).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["api-key"] = api_key
    request = urllib.request.Request(
        f"{qdrant_url}{path}",
        data=data,
        method=method,
        headers=headers,
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Qdrant HTTP {exc.code} for {path}: {details}") from exc
    except urllib.error.URLError as exc:
        raise SystemExit(f"Unable to reach Qdrant at {qdrant_url}: {exc}") from exc

    if not raw:
        return {}
    return json.loads(raw)


def document_from_payload(payload: dict[str, Any]) -> str:
    for key in ("document", "information", "text", "page_content"):
        value = payload.get(key)
        if isinstance(value, str):
            return value
    value = payload.get("content")
    if isinstance(value, str):
        return value
    return ""


def normalize_point(point: dict[str, Any]) -> dict[str, Any]:
    payload = point.get("payload") or {}
    if not isinstance(payload, dict):
        payload = {}
    metadata = payload.get("metadata") or {}
    if not isinstance(metadata, dict):
        metadata = {}
    document = document_from_payload(payload)
    return {
        "point_id": str(point.get("id", "")),
        "document": document,
        "document_sha256": hashlib.sha256(document.encode("utf-8")).hexdigest(),
        "metadata": metadata,
        "payload": payload,
    }


def write_jsonl(rows: list[dict[str, Any]], output_path: str) -> None:
    lines = [json.dumps(row, sort_keys=True, ensure_ascii=False) for row in rows]
    text = "\n".join(lines)
    if text:
        text += "\n"
    if output_path:
        path = Path(output_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    else:
        sys.stdout.write(text)


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def build_filter(
    *,
    created_gte: str = "",
    created_lte: str = "",
    project: str = "",
    kind: str = "",
    domain: str = "",
    agent: str = "",
    tags: list[str] | None = None,
    graph_status: str = "",
) -> dict[str, Any] | None:
    must: list[dict[str, Any]] = []
    created_range: dict[str, str] = {}
    if created_gte:
        created_range["gte"] = created_gte
    if created_lte:
        created_range["lte"] = created_lte
    if created_range:
        must.append({"key": "metadata.created", "range": created_range})

    for key, value in (
        ("metadata.project", project),
        ("metadata.kind", kind),
        ("metadata.domain", domain),
        ("metadata.agent", agent),
        ("graph.status", graph_status),
    ):
        if value:
            must.append({"key": key, "match": {"value": value}})

    for tag in tags or []:
        if tag:
            must.append({"key": "metadata.tags", "match": {"value": tag}})

    if not must:
        return None
    return {"must": must}


def read_json_arg(raw: str, default: Any) -> Any:
    if not raw:
        return default
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON argument: {exc}") from exc

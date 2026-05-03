#!/usr/bin/env python3
import importlib.util
import io
import json
import pathlib
import sys
import unittest
import urllib.error


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
QDRANT_DIR = REPO_ROOT / "charts/openclaw/files/workspaces/archivist/qdrant"
sys.dont_write_bytecode = True
sys.path.insert(0, str(QDRANT_DIR))


def load_module(name):
    spec = importlib.util.spec_from_file_location(name, QDRANT_DIR / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


common = load_module("_qdrant_common")
scroll_memories = load_module("scroll_memories")
set_graph_link = load_module("set_graph_link")


class ArchivistQdrantScriptTests(unittest.TestCase):
    def test_normalize_point_keeps_id_payload_metadata_and_hash(self):
        packet = common.normalize_point(
            {
                "id": "abc123",
                "payload": {
                    "document": "[real] [decision] ai-homebase uses Qdrant for semantic memory.",
                    "metadata": {
                        "agent": "architect",
                        "domain": "real",
                        "kind": "decision",
                    },
                },
            }
        )

        self.assertEqual(packet["point_id"], "abc123")
        self.assertEqual(packet["metadata"]["agent"], "architect")
        self.assertEqual(packet["payload"]["metadata"]["kind"], "decision")
        self.assertEqual(
            packet["document_sha256"],
            "01e5550a3aed7d4de7fa58eb0ab14d55ec8569986fb3936557042ec7425b7ccb",
        )

    def test_filter_construction_uses_nested_payload_keys(self):
        query_filter = common.build_filter(
            created_gte="2026-04-15T00:00:00Z",
            project="ai-homebase",
            kind="decision",
            domain="real",
            agent="architect",
            tags=["qdrant", "memgraph"],
        )
        encoded = json.dumps(query_filter, sort_keys=True)

        self.assertIn("metadata.created", encoded)
        self.assertIn("metadata.project", encoded)
        self.assertIn("metadata.kind", encoded)
        self.assertIn("metadata.domain", encoded)
        self.assertIn("metadata.agent", encoded)
        self.assertIn("metadata.tags", encoded)
        self.assertNotIn('"project"', encoded)

    def test_graph_payload_does_not_touch_document_or_metadata(self):
        class Args:
            status = "linked"
            linked_at = "2026-04-15T12:00:00Z"
            memory_slug = "qdrant:abc123"
            entity_slug = ["ai-homebase", "archivist", "ai-homebase"]
            supersedes = ["qdrant:old"]
            extra = '{"confidence":"high"}'

        graph = set_graph_link.build_graph_payload(Args)

        self.assertEqual(graph["status"], "linked")
        self.assertEqual(graph["memory_slug"], "qdrant:abc123")
        self.assertEqual(graph["linked_entity_slugs"], ["ai-homebase", "archivist"])
        self.assertEqual(graph["supersedes_memory_slugs"], ["qdrant:old"])
        self.assertEqual(graph["confidence"], "high")
        self.assertNotIn("document", graph)
        self.assertNotIn("metadata", graph)

    def test_scroll_treats_missing_collection_as_empty(self):
        def missing_collection_request(*args, **kwargs):
            self.assertTrue(kwargs["missing_collection_ok"])
            return {}

        original_request = scroll_memories.qdrant_request
        scroll_memories.qdrant_request = missing_collection_request
        try:
            rows = scroll_memories.scroll_memories(
                qdrant_url="https://qdrant.example.invalid",
                collection="openclaw-memory",
                api_key="",
                query_filter=None,
                limit=1,
                page_size=1,
            )
        finally:
            scroll_memories.qdrant_request = original_request

        self.assertEqual(rows, [])

    def test_qdrant_request_missing_collection_ok_is_narrow(self):
        original_urlopen = common.urllib.request.urlopen

        def raise_missing_collection(*args, **kwargs):
            raise urllib.error.HTTPError(
                url="https://qdrant.example.invalid/collections/openclaw-memory/points/scroll",
                code=404,
                msg="Not Found",
                hdrs=None,
                fp=io.BytesIO(b"{\"status\":{\"error\":\"Not found: Collection `openclaw-memory` doesn't exist!\"}}"),
            )

        common.urllib.request.urlopen = raise_missing_collection
        try:
            self.assertEqual(
                common.qdrant_request(
                    "https://qdrant.example.invalid",
                    "POST",
                    "/collections/openclaw-memory/points/scroll",
                    {},
                    missing_collection_ok=True,
                ),
                {},
            )
            with self.assertRaises(SystemExit):
                common.qdrant_request(
                    "https://qdrant.example.invalid",
                    "POST",
                    "/collections/openclaw-memory/points/scroll",
                    {},
                )
        finally:
            common.urllib.request.urlopen = original_urlopen

    def test_qdrant_request_other_404_remains_fatal(self):
        original_urlopen = common.urllib.request.urlopen

        def raise_other_404(*args, **kwargs):
            raise urllib.error.HTTPError(
                url="https://qdrant.example.invalid/collections/openclaw-memory/points/scroll",
                code=404,
                msg="Not Found",
                hdrs=None,
                fp=io.BytesIO(b'{"status":{"error":"different not found"}}'),
            )

        common.urllib.request.urlopen = raise_other_404
        try:
            with self.assertRaises(SystemExit):
                common.qdrant_request(
                    "https://qdrant.example.invalid",
                    "POST",
                    "/collections/openclaw-memory/points/scroll",
                    {},
                    missing_collection_ok=True,
                )
        finally:
            common.urllib.request.urlopen = original_urlopen


if __name__ == "__main__":
    unittest.main()

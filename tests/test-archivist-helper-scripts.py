#!/usr/bin/env python3
import importlib.util
import json
import pathlib
import sys
import tempfile
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
ARCHIVIST_DIR = REPO_ROOT / "charts/openclaw/files/workspaces/archivist"
sys.dont_write_bytecode = True


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


run_query = load_module("run_query", ARCHIVIST_DIR / "queries/run_query.py")
update_checkpoint = load_module("update_checkpoint", ARCHIVIST_DIR / "grooming/update_checkpoint.py")


class ArchivistHelperScriptTests(unittest.TestCase):
    def test_run_query_renders_cypher_literals_and_null_defaults(self):
        rendered = run_query.render_query(
            "MATCH (e:Entity {slug: $slug}) SET e.tags = $tags, e.note = $missing RETURN e;",
            {"slug": "ai-homebase", "tags": ["qdrant", "memgraph"]},
            strict=False,
        )

        self.assertIn("slug: 'ai-homebase'", rendered)
        self.assertIn("e.tags = ['qdrant', 'memgraph']", rendered)
        self.assertIn("e.note = null", rendered)

    def test_run_query_strict_fails_missing_parameters(self):
        with self.assertRaises(SystemExit):
            run_query.render_query("RETURN $required;", {}, strict=True)

    def test_update_checkpoint_deep_merges_and_sets_dotted_paths(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            checkpoint_path = pathlib.Path(temp_dir) / "grooming-checkpoint.json"
            checkpoint_path.write_text(
                json.dumps(
                    {
                        "version": 1,
                        "last_run": {"run_id": "old-run", "status": "success"},
                        "nextcloud": {"surfaces": {"Desk/index.md": {"size": 12}}},
                    }
                ),
                encoding="utf-8",
            )

            checkpoint = update_checkpoint.load_checkpoint(checkpoint_path)
            checkpoint = update_checkpoint.deep_merge(
                checkpoint,
                {"last_run": {"run_id": "new-run"}, "nextcloud": {"last_successful_scan": "2026-04-15T12:00:00Z"}},
            )
            update_checkpoint.set_dotted(checkpoint, "last_run.status", "aborted")

            self.assertEqual(checkpoint["last_run"]["run_id"], "new-run")
            self.assertEqual(checkpoint["last_run"]["status"], "aborted")
            self.assertEqual(checkpoint["nextcloud"]["surfaces"]["Desk/index.md"]["size"], 12)
            self.assertEqual(checkpoint["nextcloud"]["last_successful_scan"], "2026-04-15T12:00:00Z")


if __name__ == "__main__":
    unittest.main()

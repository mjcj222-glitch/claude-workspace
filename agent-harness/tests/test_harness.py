import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import harness


class HarnessTests(unittest.TestCase):
    def test_workspace_validates(self):
        harness.validate_workspace()

    def test_topic_ids_unique(self):
        payload = {"schema_version": 1, "topics": [
            {"id": "sample", "status": "active", "title": "A", "goal": "G", "questions": ["Q"]},
            {"id": "sample", "status": "paused", "title": "B", "goal": "G", "questions": ["Q"]},
        ]}
        with self.assertRaisesRegex(ValueError, "duplicate"):
            harness.validate_topics(payload)

    def test_rejects_path_traversal_id(self):
        payload = {"schema_version": 1, "topics": [
            {"id": "../../etc", "status": "active", "title": "A", "goal": "G", "questions": ["Q"]},
        ]}
        with self.assertRaisesRegex(ValueError, "invalid topic id"):
            harness.validate_topics(payload)

    def test_brief_includes_goal_and_rules(self):
        topic = harness.load_topics()[0]
        text = harness.render_brief(topic, "verify")
        self.assertIn(topic["goal"], text)
        self.assertIn("검증", text)

    def test_default_topic_is_active(self):
        topics = harness.load_topics()
        self.assertTrue(any(t["status"] == "active" for t in topics))


if __name__ == "__main__":
    unittest.main()

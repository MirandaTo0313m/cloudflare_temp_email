#!/usr/bin/env python3
"""
Test script for send_release_to_telegram.py

Runs basic unit tests and integration checks for the release notification script.
Usage:
    python test_send_release.py
    python test_send_release.py --integration  # requires valid config.json
"""

import json
import os
import sys
import unittest
from unittest.mock import MagicMock, patch

# Ensure the scripts directory is in path
sys.path.insert(0, os.path.dirname(__file__))

from send_release_to_telegram import md_escape, md_render, load_config


class TestMdEscape(unittest.TestCase):
    """Tests for the md_escape helper function."""

    def test_escapes_special_characters(self):
        special = r"_*[]()~`>#+-=|{}.!"
        result = md_escape(special)
        for ch in special:
            self.assertIn(f"\\{ch}", result)

    def test_plain_text_unchanged(self):
        text = "hello world 123"
        self.assertEqual(md_escape(text), text)

    def test_empty_string(self):
        self.assertEqual(md_escape(""), "")

    def test_mixed_content(self):
        result = md_escape("v1.0.0 (release)")
        self.assertIn("v1", result)
        self.assertIn("\\.", result)
        self.assertIn("\\(", result)
        self.assertIn("\\)", result)


class TestMdRender(unittest.TestCase):
    """Tests for the md_render Markdown-to-MarkdownV2 renderer."""

    def test_bold_conversion(self):
        result = md_render("**bold text**")
        self.assertIn("*bold text*", result)

    def test_code_block(self):
        result = md_render("```\nsome code\n```")
        self.assertIn("`", result)

    def test_inline_code(self):
        result = md_render("`inline`")
        self.assertIn("`inline`", result)

    def test_heading_stripped(self):
        """Headings should be rendered as bold or plain text, not with # symbols."""
        result = md_render("## Section Title")
        self.assertNotIn("##", result)

    def test_empty_input(self):
        result = md_render("")
        self.assertEqual(result.strip(), "")


class TestLoadConfig(unittest.TestCase):
    """Tests for the load_config function."""

    def test_loads_valid_config(self, tmp_path=None):
        import tempfile

        config_data = {
            "bot_token": "123456:ABC-DEF",
            "chat_id": "-1001234567890",
        }
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False
        ) as f:
            json.dump(config_data, f)
            tmp_name = f.name

        try:
            cfg = load_config(tmp_name)
            self.assertEqual(cfg["bot_token"], "123456:ABC-DEF")
            self.assertEqual(cfg["chat_id"], "-1001234567890")
        finally:
            os.unlink(tmp_name)

    def test_missing_file_raises(self):
        with self.assertRaises((FileNotFoundError, SystemExit)):
            load_config("/nonexistent/path/config.json")


class TestIntegration(unittest.TestCase):
    """Integration tests — skipped unless --integration flag is passed."""

    @unittest.skipUnless("--integration" in sys.argv, "integration tests skipped")
    def test_fetch_real_release(self):
        """Fetch the latest real release from GitHub and verify shape."""
        from send_release_to_telegram import fetch_release

        release = fetch_release(
            "dreamhunter2333", "cloudflare_temp_email", tag=None
        )
        self.assertIn("tag_name", release)
        self.assertIn("body", release)
        self.assertIn("html_url", release)
        print(f"\nFetched release: {release['tag_name']}")

    @unittest.skipUnless("--integration" in sys.argv, "integration tests skipped")
    def test_send_real_notification(self):
        """Send a test notification using config.json (requires valid token)."""
        from send_release_to_telegram import load_config, build_message, send_message

        config_path = os.path.join(os.path.dirname(__file__), "..", "config.json")
        cfg = load_config(config_path)

        fake_release = {
            "tag_name": "v0.0.0-test",
            "name": "Test Release",
            "body": "This is a **test** notification from the CI script.",
            "html_url": "https://github.com/dreamhunter2333/cloudflare_temp_email/releases",
            "published_at": "2024-01-01T00:00:00Z",
        }

        message = build_message(fake_release)
        self.assertTrue(len(message) > 0)
        result = send_message(cfg["bot_token"], cfg["chat_id"], message)
        self.assertTrue(result.get("ok"), f"Telegram API error: {result}")
        print("\nTest notification sent successfully.")


if __name__ == "__main__":
    # Remove custom flag before passing to unittest
    argv = [a for a in sys.argv if a != "--integration"]
    unittest.main(argv=argv, verbosity=2)

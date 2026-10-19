#!/usr/bin/env python3
"""Zero-API-cost research harness helper. Never invokes an AI model."""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TOPICS_PATH = ROOT / "topics.json"
ROLES = ("research", "verify", "build", "report")
TOPIC_ID = re.compile(r"^[a-z][a-z0-9-]{1,49}$")


def validate_topics(payload: object) -> list[dict]:
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise ValueError("schema_version must be 1")
    topics = payload.get("topics")
    if not isinstance(topics, list):
        raise ValueError("topics must be a list")
    seen: set[str] = set()
    for topic in topics:
        if not isinstance(topic, dict):
            raise ValueError("each topic must be an object")
        ident = topic.get("id")
        if not isinstance(ident, str) or not TOPIC_ID.fullmatch(ident):
            raise ValueError(f"invalid topic id: {ident!r}")
        if ident in seen:
            raise ValueError(f"duplicate topic id: {ident}")
        seen.add(ident)
        if topic.get("status") not in {"active", "paused", "done"}:
            raise ValueError(f"{ident}: invalid status")
        for field in ("title", "goal"):
            if not isinstance(topic.get(field), str) or not topic[field].strip():
                raise ValueError(f"{ident}: {field} required")
        q = topic.get("questions")
        if not isinstance(q, list) or not q or not all(isinstance(x, str) and x.strip() for x in q):
            raise ValueError(f"{ident}: nonempty questions required")
    return topics


def load_topics(path: Path = TOPICS_PATH) -> list[dict]:
    return validate_topics(json.loads(path.read_text(encoding="utf-8")))


def topic_by_id(topics: list[dict], ident: str) -> dict:
    for t in topics:
        if t["id"] == ident:
            return t
    raise ValueError(f"unknown topic: {ident}")


def validate_workspace() -> None:
    topics = load_topics()
    mandatory = ["AGENTS.md", "README.md", "reports/REPORT_TEMPLATE.md",
                 "prompts/dot-start.md", "prompts/codex-first-task.md"]
    mandatory += [f"roles/{role}.md" for role in ROLES]
    missing = [p for p in mandatory if not (ROOT / p).is_file()]
    if missing:
        raise ValueError(f"missing required files: {', '.join(missing)}")
    print(f"OK: {len(topics)} research topic(s), {len(ROLES)} role(s), templates present.")


def render_brief(topic: dict, role: str) -> str:
    if role not in ROLES:
        raise ValueError(f"invalid role: {role}")
    rule = (ROOT / "roles" / f"{role}.md").read_text(encoding="utf-8")
    questions = "\n".join(f"{i}. {q}" for i, q in enumerate(topic["questions"], 1))
    return (
        f"# 작업 지시 — {topic['title']}\n"
        f"주제 ID: {topic['id']}\n"
        f"목표: {topic['goal']}\n"
        f"오늘 확인할 질문:\n{questions}\n\n"
        f"역할 규칙:\n{rule}\n"
        "근거와 검증 상태를 명확히 하고, 승인 없이 결제/게시/대량 변경하지 말 것.\n"
    )


def create_report_template(topic: dict, day: str) -> Path:
    parsed = dt.date.fromisoformat(day)
    if parsed.isoformat() != day:
        raise ValueError("date must be YYYY-MM-DD")
    dest = ROOT / "reports" / day / (topic["id"] + ".md")
    if dest.exists():
        raise ValueError(f"report already exists: {dest}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    text = (ROOT / "reports" / "REPORT_TEMPLATE.md").read_text(encoding="utf-8")
    text = text.replace("<YYYY-MM-DD>", day).replace("<topic-id>", topic["id"])
    dest.write_text(text, encoding="utf-8")
    return dest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="API-free harness planning and validation")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("check")
    sub.add_parser("status")
    brief = sub.add_parser("brief")
    brief.add_argument("--topic", required=True)
    brief.add_argument("--role", required=True, choices=ROLES)
    report = sub.add_parser("report-template")
    report.add_argument("--topic", required=True)
    report.add_argument("--date", required=True, help="YYYY-MM-DD")
    args = parser.parse_args(argv)
    try:
        if args.command == "check":
            validate_workspace()
        else:
            topics = load_topics()
            if args.command == "status":
                for t in topics:
                    print(f"[{t['status']}] {t['id']}: {t['title']}")
                print("AI runtime: not started by this tool; set up dot and Codex Cloud.")
            elif args.command == "brief":
                print(render_brief(topic_by_id(topics, args.topic), args.role))
            elif args.command == "report-template":
                print(f"Created: {create_report_template(topic_by_id(topics, args.topic), args.date)}")
    except (OSError, ValueError, json.JSONDecodeError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

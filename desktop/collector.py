#!/usr/bin/env python3
"""AI Usage Monitor — desktop collector.

Reads local usage data from supported AI platforms (Command Code, Cursor),
normalizes it into a portable snapshot, and optionally serves it over LAN
for the mobile app to pull.

Stdlib only. Run as the desktop user (not root).

Usage:
  python3 collector.py collect [--full]        # print snapshot JSON to stdout
  python3 collector.py export <out.json>       # write snapshot file
  python3 collector.py serve [--port 8765]     # HTTP server for the app
  python3 collector.py health                  # print what was found
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
import time
from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Iterable

SNAPSHOT_VERSION = 1

DEFAULT_CC_HOME = Path(os.environ.get("HOME", str(Path.home()))) / ".commandcode"
DEFAULT_CURSOR_DB = Path(os.environ.get("HOME", str(Path.home()))) / ".omp/agent/agent.db"


# ---------------------------------------------------------------------------
# Command Code source
# ---------------------------------------------------------------------------

_SESSION_RE = re.compile(r"^(?P<id>[0-9a-f-]{8,})\.jsonl$")


def _cc_accounts(cc_home: Path) -> list[dict[str, Any]]:
    """Current account from auth.json. CC has one active login at a time."""
    auth = cc_home / "auth.json"
    if not auth.exists():
        return []
    try:
        d = json.loads(auth.read_text())
    except (json.JSONDecodeError, OSError):
        return []
    key = d.get("userId") or d.get("userName") or "unknown"
    return [{
        "key": f"cc:{key}",
        "label": d.get("userName") or d.get("userId") or "Command Code",
        "email": d.get("userName", ""),
        "last_seen": int(time.time() * 1000),
    }]


def _cc_events(cc_home: Path) -> tuple[list[dict[str, Any]], int]:
    """Parse per-message usage from project transcripts.

    Returns (events, cursor_ms) where cursor_ms is the max message timestamp.
    Incremental sync is handled by the caller via file mtimes; here we read
    everything and dedupe by raw_id downstream.
    """
    events: list[dict[str, Any]] = []
    projects_dir = cc_home / "projects"
    if not projects_dir.is_dir():
        return events, 0
    for project_dir in projects_dir.iterdir():
        if not project_dir.is_dir():
            continue
        for f in project_dir.iterdir():
            if not (_SESSION_RE.match(f.name) and f.suffix == ".jsonl"):
                continue
            events.extend(_cc_session_events(f, project_dir.name))
    max_ts = max((e["ts"] for e in events), default=0)
    return events, max_ts


def _cc_session_events(f: Path, project: str) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    try:
        lines = f.read_text(errors="replace").splitlines()
    except OSError:
        return events
    for line in lines:
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if d.get("type") != "message":
            continue
        msg = d.get("message") or {}
        if msg.get("role") != "assistant":
            continue
        usage = d.get("usage")  # top-level per-message usage record
        if not isinstance(usage, dict):
            continue
        events.append({
            "platform": "commandcode",
            "account_key": "cc:current",  # refined by collector: replaced by userId below
            "account_label": "Command Code",
            "model": d.get("model") or "",
            "ts": _ts_ms(d.get("timestamp")),
            "input_tokens": usage.get("inputTokens", 0),
            "output_tokens": usage.get("outputTokens", 0),
            "cache_read_tokens": usage.get("cacheReadTokens", 0),
            "cache_write_tokens": usage.get("cacheWriteTokens", 0),
            "cost_usd": usage.get("costUsd", 0.0),
            "source": project,
            "raw_id": f"{f.stem}:{d.get('id', '')}",
        })
    return events


def _ts_ms(ts: str) -> int:
    try:
        # "2026-08-16T21:43:23.228Z" -> ms since epoch
        s = ts.replace("Z", "+00:00")
        dt = time.strptime(s.split(".")[0], "%Y-%m-%dT%H:%M:%S")
        import calendar
        ms = calendar.timegm(dt) * 1000
        frac = s.split(".")[1][:3] if "." in s else "000"
        return ms + int(frac.ljust(3, "0"))
    except (ValueError, IndexError):
        return 0


# ---------------------------------------------------------------------------
# Cursor source
# ---------------------------------------------------------------------------


def _cursor_accounts(db_path: Path) -> list[dict[str, Any]]:
    """Accounts from auth_credentials; fall back to email when available."""
    if not db_path.exists():
        return []
    try:
        con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    except sqlite3.Error:
        return []
    try:
        rows = con.execute(
            "SELECT provider, identity_key, data FROM auth_credentials"
        ).fetchall()
    except sqlite3.Error:
        rows = []
    finally:
        con.close()
    out: list[dict[str, Any]] = []
    seen: set[str] = set()
    for provider, identity_key, data in rows:
        email = ""
        try:
            d = json.loads(data or "{}")
            email = d.get("email", "")
        except json.JSONDecodeError:
            pass
        key = identity_key or f"cursor:{provider}:{email or 'unknown'}"
        if key in seen:
            continue
        seen.add(key)
        out.append({
            "key": key,
            "label": email or provider,
            "email": email,
            "last_seen": int(time.time() * 1000),
        })
    return out


def _cursor_events(db_path: Path) -> tuple[list[dict[str, Any]], int]:
    if not db_path.exists():
        return [], 0
    try:
        con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    except sqlite3.Error:
        return [], 0
    events: list[dict[str, Any]] = []
    try:
        rows = con.execute(
            "SELECT id, recorded_at, provider, account_key, model, requests,"
            " input_tokens, output_tokens, cache_read_tokens, cache_write_tokens,"
            " cost_usd FROM client_usage"
        ).fetchall()
    except sqlite3.Error:
        rows = []
    for r in rows:
        (rid, recorded_at, provider, account_key, model, requests,
         itok, otok, crtok, cwtok, cost) = r
        events.append({
            "platform": "cursor",
            "account_key": str(account_key or "cursor:unknown"),
            "account_label": str(account_key or "Cursor"),
            "model": str(model or provider or ""),
            "ts": int(recorded_at or 0),
            "input_tokens": int(itok or 0),
            "output_tokens": int(otok or 0),
            "cache_read_tokens": int(crtok or 0),
            "cache_write_tokens": int(cwtok or 0),
            "cost_usd": float(cost or 0.0),
            "source": "agent.db:client_usage",
            "raw_id": f"client_usage:{rid}",
        })
    max_ts = max((e["ts"] for e in events), default=0)
    con.close()
    return events, max_ts


def _cursor_limits(db_path: Path) -> list[dict[str, Any]]:
    if not db_path.exists():
        return []
    try:
        con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    except sqlite3.Error:
        return []
    try:
        rows = con.execute(
            "SELECT provider, account_key, email, limit_id, label, used_fraction,"
            " status, resets_at, recorded_at FROM usage_history"
        ).fetchall()
    except sqlite3.Error:
        rows = []
    con.close()
    return [{
        "id": f"cursor:{provider}:{account_key}:{limit_id}",
        "platform": "cursor",
        "account_key": str(account_key or "cursor:unknown"),
        "label": str(label or ""),
        "limit_id": str(limit_id),
        "used_fraction": float(used_fraction or 0.0),
        "status": str(status or ""),
        "resets_at": int(resets_at or 0),
        "recorded_at": int(recorded_at or 0),
    } for (provider, account_key, _email, limit_id, label, used_fraction,
           status, resets_at, recorded_at) in rows]


# ---------------------------------------------------------------------------
# Snapshot assembly
# ---------------------------------------------------------------------------


@dataclass
class Collector:
    cc_home: Path = DEFAULT_CC_HOME
    cursor_db: Path = DEFAULT_CURSOR_DB
    events: list[dict[str, Any]] = field(default_factory=list)
    limits: list[dict[str, Any]] = field(default_factory=list)
    accounts: list[dict[str, Any]] = field(default_factory=list)
    max_ts: int = 0
    collected_ms: int = field(default_factory=lambda: int(time.time() * 1000))

    def collect(self) -> "Collector":
        cc_events, cc_max = _cc_events(self.cc_home)
        cur_events, cur_max = _cursor_events(self.cursor_db)
        self.accounts = _cc_accounts(self.cc_home) + _cursor_accounts(self.cursor_db)
        self.limits = _cursor_limits(self.cursor_db)
        # Resolve the CC "current" placeholder to a real account key.
        if self.accounts:
            cc_acc = next((a for a in self.accounts if a["key"].startswith("cc:")), None)
            if cc_acc:
                for e in cc_events:
                    e["account_key"] = cc_acc["key"]
                    e["account_label"] = cc_acc["label"]
        self.events = cc_events + cur_events
        self.max_ts = max(cc_max, cur_max, 0)
        return self

    def snapshot(self, since_ms: int = 0) -> dict[str, Any]:
        if since_ms:
            events = [e for e in self.events if e["ts"] > since_ms]
        else:
            events = self.events
        return {
            "version": SNAPSHOT_VERSION,
            "collected_at": self.collected_ms,
            "cursor": self.max_ts,
            "events": events,
            "limits": self.limits,
            "accounts": self.accounts,
        }

    def health(self) -> dict[str, Any]:
        return {
            "platforms": {
                "commandcode": {
                    "projects_dir": str(self.cc_home / "projects"),
                    "exists": (self.cc_home / "projects").is_dir(),
                    "events": sum(1 for e in self.events if e["platform"] == "commandcode"),
                },
                "cursor": {
                    "agent_db": str(self.cursor_db),
                    "exists": self.cursor_db.exists(),
                    "events": sum(1 for e in self.events if e["platform"] == "cursor"),
                    "limits": len(self.limits),
                    "accounts": len(self.accounts),
                },
            },
            "accounts": self.accounts,
            "total_events": len(self.events),
            "max_ts": self.max_ts,
            "collected_at": self.collected_ms,
        }


# ---------------------------------------------------------------------------
# HTTP server
# ---------------------------------------------------------------------------


def make_handler(collector: Collector, since: int = 0):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *a):  # quiet
            pass

        def _send(self, code: int, body: bytes, ctype: str = "application/json"):
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path.startswith("/health"):
                collector.collect()
                self._send(200, json.dumps(collector.health()).encode())
            elif self.path.startswith("/export"):
                q = self.path.split("?", 1)[-1]
                since_ms = 0
                for part in q.split("&"):
                    k, _, v = part.partition("=")
                    if k == "since":
                        try:
                            since_ms = int(v)
                        except ValueError:
                            pass
                collector.collect()
                body = json.dumps(collector.snapshot(since_ms=since_ms)).encode()
                self._send(200, body)
            else:
                self._send(404, json.dumps({"error": "not found"}).encode())

    return Handler


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="AI usage desktop collector")
    ap.add_argument("--cc-home", type=Path, default=DEFAULT_CC_HOME)
    ap.add_argument("--cursor-db", type=Path, default=DEFAULT_CURSOR_DB)
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("health")
    sub.add_parser("collect")

    ex = sub.add_parser("export")
    ex.add_argument("out", type=Path)

    sv = sub.add_parser("serve")
    sv.add_argument("--port", type=int, default=8765)
    sv.add_argument("--host", default="0.0.0.0")

    args = ap.parse_args(argv)
    collector = Collector(cc_home=args.cc_home, cursor_db=args.cursor_db)
    collector.collect()

    if args.cmd == "health":
        print(json.dumps(collector.health(), indent=2))
    elif args.cmd == "collect":
        print(json.dumps(collector.snapshot(), indent=2))
    elif args.cmd == "export":
        args.out.write_text(json.dumps(collector.snapshot(), indent=2))
        print(f"wrote {len(collector.events)} events, {len(collector.limits)} limits, "
              f"{len(collector.accounts)} accounts to {args.out}")
    elif args.cmd == "serve":
        server = ThreadingHTTPServer((args.host, args.port), make_handler(collector))
        print(f"serving on http://{args.host}:{args.port} "
              f"(cc={collector.cc_home}, cursor={collector.cursor_db})")
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nstopped")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Poll the repos in repos/tracked.json and regenerate the hub status files."""

from __future__ import annotations

import json
import os
import re
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parent.parent
TRACKED = ROOT / "repos" / "tracked.json"
STATE = ROOT / "data" / "last-seen.json"
README = ROOT / "README.md"
STATUS = ROOT / "docs" / "STATUS.md"
CHANGELOG = ROOT / "CHANGELOG.md"

API = "https://api.github.com"
GONE = {404, 409, 422, 451}
ATTEMPTS = 4
REFRESHED = ("pushed_at", "version", "version_url", "blocks")

STATUS_HEADER = """\
# STATUS — generated

> Regenerated every 15 minutes by `gfx906-hub-check.py`; a run commits only when the table changes.
> The README blocks are the digest of this file. Hand edits will be overwritten.

_Last data change: {last_change}._

| repo | category | role | ref | head | updated | version | compare |
|---|---|---|---|---|---|---|---|
"""
BLOCK_HEADER = "| repo | focus | updated | head | version |\n|---|---|---|---|---|\n"


def api(path: str, token: str | None):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "gfx906-hub-check"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(API + path, headers=headers)
    for attempt in range(1, ATTEMPTS + 1):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            if error.code in GONE:
                return None
            limited = error.headers.get("x-ratelimit-remaining") == "0" or error.headers.get("retry-after")
            if error.code == 403 and not limited:
                return None
            if error.code < 500 or attempt == ATTEMPTS:
                raise
        except (urllib.error.URLError, TimeoutError):
            if attempt == ATTEMPTS:
                raise
        time.sleep(2**attempt)


def probe_atom(repo: dict) -> str | None:
    """Cheap move-probe via the public commits.atom feed (unauthenticated,
    not subject to API rate limits). Returns the first entry's commit SHA,
    or None when the feed can't be fetched or parsed — the caller then
    falls back to the full API poll."""
    url = f"https://github.com/{repo['owner']}/{repo['name']}/commits.atom"
    request = urllib.request.Request(url, headers={"User-Agent": "gfx906-hub-check"})
    text = ""
    for attempt in range(1, ATTEMPTS + 1):
        try:
            with urllib.request.urlopen(request, timeout=20) as feed:
                text = feed.read(32768).decode("utf-8", "replace")
            break
        except (urllib.error.URLError, TimeoutError, OSError):
            if attempt == ATTEMPTS:
                return None
            time.sleep(2**attempt)
    match = re.search(r"<entry>.*?/commit/([0-9a-f]{40})", text, re.S)
    return match.group(1) if match else None


def poll(repo: dict, token: str | None) -> dict | None:
    base = f"/repos/{repo['owner']}/{repo['name']}"
    ref = repo.get("ref") or "HEAD"
    info = api(base, token)
    head = info and api(f"{base}/commits/{quote(ref)}", token)
    if not head:
        return None
    polled = {"sha": head["sha"], "pushed_at": info["pushed_at"][:10]}

    release = api(f"{base}/releases/latest", token)
    if release:
        polled["version"], polled["version_url"] = release["tag_name"], release["html_url"]
    else:
        tags = api(f"{base}/tags?per_page=1", token)
        if tags:
            polled["version"], polled["version_url"] = tags[0]["name"], None

    paths = repo.get("block_paths")
    if paths:
        polled["blocks"] = {}
        for block, path in paths.items():
            query = f"path={quote(path, safe='')}&per_page=1"
            if ref != "HEAD":
                query += f"&sha={quote(ref, safe='')}"
            commits = api(f"{base}/commits?{query}", token)
            if commits:
                polled["blocks"][block] = {
                    "sha": commits[0]["sha"],
                    "date": commits[0]["commit"]["author"]["date"][:10],
                }
    return polled


def refresh(tracked: dict, old: dict, today: str, token: str | None) -> tuple[dict, list[dict]]:
    ids = {repo["id"] for repo in tracked["repos"]}
    state = {key: value for key, value in old.items() if key in ids or key.startswith("_")}
    active = [repo for repo in tracked["repos"] if repo.get("status", "active") == "active"]
    changed, unreachable = [], []
    for repo in active:
        seen = state.get(repo["id"])
        if (repo.get("ref") or "HEAD") == "HEAD" and seen and seen.get("sha"):
            probe = probe_atom(repo)
            if probe is not None and probe == seen["sha"]:
                continue  # no move since last run — entry stays byte-identical
        polled = poll(repo, token)
        if polled is None:
            unreachable.append(repo["id"])
            continue
        previous = state.get(repo["id"])
        if previous is None or previous["sha"] != polled["sha"]:
            entry = {"sha": polled["sha"], "prev": previous and previous["sha"], "date": today}
            if previous:
                changed.append(repo)
        else:
            entry = {key: value for key, value in previous.items() if key not in REFRESHED}
        entry.update({key: polled[key] for key in REFRESHED if key in polled})
        state[repo["id"]] = entry
    state["_unreachable"] = unreachable
    state["_tracked_count"] = len(active)
    return state, changed


def categories_of(repo: dict) -> list[str]:
    return repo.get("categories") or [repo["category"]]


def version_cell(entry: dict, empty: str) -> str:
    version, url = entry.get("version"), entry.get("version_url")
    if not version:
        return empty
    return f"[{version}]({url})" if url else version


def render_blocks(tracked: dict, state: dict) -> str:
    out = ""
    for category in tracked["categories"]:
        rows = []
        for repo in tracked["repos"]:
            entry = state.get(repo["id"])
            if entry is None or category not in categories_of(repo):
                continue
            block = entry.get("blocks", {}).get(category, {})
            updated = block.get("date") or entry["pushed_at"]
            sha = block.get("sha") or entry["sha"]
            ref = repo.get("ref") or "HEAD"
            link = repo.get("block_links", {}).get(category) or (
                repo["remote"] if ref == "HEAD" else f"{repo['remote']}/tree/{ref}"
            )
            rows.append(
                (
                    updated,
                    f"| [{repo['owner']}/{repo['name']}]({link}) | {repo.get('focus', '')} | {updated}"
                    f" | `{sha[:8]}` | {version_cell(entry, '—')} |\n",
                )
            )
        rows.sort(key=lambda row: row[0], reverse=True)
        table = BLOCK_HEADER + "".join(row for _, row in rows) if rows else "_(none tracked)_\n"
        out += f"### {category}\n\n{table}\n"
    return out


def render_status(tracked: dict, state: dict, last_change: str) -> str:
    out = STATUS_HEADER.format(last_change=last_change)
    for repo in tracked["repos"]:
        entry = state.get(repo["id"])
        if entry is None:
            continue
        compare = f"{repo['remote']}/compare/{entry['prev']}...{entry['sha']}" if entry.get("prev") else "-"
        out += (
            f"| {repo['owner']}/{repo['name']} | {', '.join(categories_of(repo))} | {repo.get('role', '')}"
            f" | `{repo.get('ref') or 'HEAD'}` | `{entry['sha'][:8]}` | {entry['pushed_at']}"
            f" | {version_cell(entry, '-')} | {compare} |\n"
        )
    return out


def replace_block(text: str, name: str, body: str) -> str:
    begin, end = f"<!-- HUB-{name}:BEGIN -->", f"<!-- HUB-{name}:END -->"
    head, found_begin, rest = text.partition(begin)
    _, found_end, tail = rest.partition(end)
    if not (found_begin and found_end):
        raise SystemExit(f"README.md: HUB-{name} markers not found")
    return f"{head}{begin}\n{body}{end}{tail}"


def add_to_changelog(text: str, today: str, changed: list[dict], state: dict) -> str:
    entries = ""
    for repo in changed:
        entry = state[repo["id"]]
        compare = f"{repo['remote']}/compare/{entry['prev']}...{entry['sha']}"
        entries += (
            f"- **{repo['owner']}/{repo['name']}** `{entry['prev'][:8]}` → `{entry['sha'][:8]}`"
            f" ([compare]({compare}))\n"
        )
    if not text.endswith("\n"):
        text += "\n"
    heading = f"## {today}\n"
    start = f"\n{text}".find(f"\n{heading}")
    if start == -1:
        at = text.find("\n## ")
        at = len(text) if at == -1 else at + 1
        return f"{text[:at]}{heading}{entries}\n{text[at:]}"
    end = text.find("\n## ", start)
    end = len(text) if end == -1 else end + 1
    rest = text[end:]
    return text[:start] + text[start:end].rstrip("\n") + "\n" + entries + (f"\n{rest}" if rest else "")


def main() -> None:
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    now = datetime.now(timezone.utc)
    today = now.strftime("%Y-%m-%d")

    tracked = json.loads(TRACKED.read_text(encoding="utf-8"))
    old = json.loads(STATE.read_text(encoding="utf-8")) if STATE.exists() else {}
    state, changed = refresh(tracked, old, today, token)
    unreachable = state["_unreachable"]
    last_change = today if changed else (old.get("_last_change") or today)
    state["_last_change"] = last_change

    readme = README.read_text(encoding="utf-8")
    readme = replace_block(readme, "STATUS", render_blocks(tracked, state))
    footer = (
        f"_Hub status last updated: {last_change} — {state['_tracked_count']} tracked,"
        f" {len(unreachable)} unreachable._\n"
    )
    readme = replace_block(readme, "FOOTER", footer)

    STATE.write_text(json.dumps(state, indent=1) + "\n", encoding="utf-8")
    README.write_text(readme, encoding="utf-8")
    STATUS.write_text(render_status(tracked, state, last_change), encoding="utf-8")
    if changed:
        changelog = CHANGELOG.read_text(encoding="utf-8")
        CHANGELOG.write_text(add_to_changelog(changelog, today, changed, state), encoding="utf-8")

    if changed:
        message = f"hub: {len(changed)} changed ({', '.join(repo['id'] for repo in changed)})"
    else:
        message = "hub: no changes (nothing committed)"
    for repo_id in unreachable:
        print(f"::warning::unreachable: {repo_id}")
    print(message)
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as handle:
            handle.write(f"message={message}\n")


if __name__ == "__main__":
    main()

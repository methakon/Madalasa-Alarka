#!/usr/bin/env python3
"""Source-preserving Markdown destinations, GFM anchors and offline link checks.

The CommonMark parser identifies code blocks/reference definitions. Destination
spans alone are edited; prose, code, whitespace, link labels/titles and external
URLs are never serialized or replaced. No network requests are made.
"""
from __future__ import annotations

import html
import posixpath
import re
import unicodedata
from pathlib import Path
from urllib.parse import unquote, urlsplit

from markdown_it import MarkdownIt
from markdown_it.helpers import parseLinkDestination


def parser():
    return MarkdownIt("commonmark", {"html": True}).enable("table")


def external(url):
    return bool(re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", url)) or url.startswith("//")


def destination_spans(text):
    """Return destination offsets, excluding surrounding <>, code and autolinks."""
    env = {}
    tokens = parser().parse(text, env)
    lines = text.splitlines(keepends=True)
    offsets = [0]
    for line in lines:
        offsets.append(offsets[-1] + len(line))
    masked = list(text)
    for token in tokens:
        if token.type in {"fence", "code_block"} and token.map:
            start, end = (offsets[n] for n in token.map)
            masked[start:end] = " " * (end - start)
    # Inline code uses matching runs of backticks, not a first-backtick regex.
    working = "".join(masked)
    pos = 0
    while pos < len(working):
        if working[pos] != "`":
            pos += 1
            continue
        stop = pos
        while stop < len(working) and working[stop] == "`":
            stop += 1
        run = working[pos:stop]
        close = re.search(r"(?<!`)" + re.escape(run) + r"(?!`)", working[stop:])
        if close:
            end = stop + close.end()
            masked[pos:end] = " " * (end - pos)
            pos = end
        else:
            pos = stop
    working = "".join(masked)
    spans = set()

    def add_destination(pos):
        result = parseLinkDestination(text, pos, len(text))
        if result.ok:
            if text[pos:pos + 1] == "<":
                spans.add((pos + 1, result.pos - 1))
            else:
                spans.add((pos, result.pos))

    for match in re.finditer(r"(?<!\\)\]\(\s*", working):
        add_destination(match.end())
    for reference in env.get("references", {}).values():
        start, end = reference["map"]
        segment = working[offsets[start]:offsets[end]]
        match = re.match(r" {0,3}\[[^\]\n]+\]:\s*", segment)
        if match:
            add_destination(offsets[start] + match.end())
    # HTML destinations are real navigation too, but HTML inside code is masked.
    for tag in re.finditer(r"<[A-Za-z][^<>]*>", working):
        for attr in re.finditer(r"\b(?:href|src)\s*=\s*([\"'])(.*?)\1", tag.group(), re.I):
            spans.add((tag.start() + attr.start(2), tag.start() + attr.end(2)))
    return sorted(spans)


def rewrite_links(text, transform):
    for start, end in reversed(destination_spans(text)):
        old = text[start:end]
        if old and not external(old):
            text = text[:start] + transform(old) + text[end:]
    return text


def normalized_content(text):
    """Mask ONLY local destinations, preserving every other original byte."""
    return rewrite_links(text, lambda _: "__LOCAL_DESTINATION__")


def destination_identity(url, source_path, legacy_map):
    """Logical repository target plus query/fragment, independent of file depth."""
    if external(url):
        return url
    parsed = urlsplit(html.unescape(url))
    name = unquote(parsed.path).replace("\\", "")
    if not name:
        target = source_path
    elif name.startswith('/'):
        target = name.lstrip('/')
    else:
        target = posixpath.normpath(posixpath.join(posixpath.dirname(source_path), name))
    return (legacy_map.get(target, target), parsed.query, unquote(parsed.fragment))


def strip_control_header(text):
    pattern = r"\A<!-- document-control:start -->\n.*?<!-- document-control:end -->\n\n"
    return re.sub(pattern, "", text, count=1, flags=re.S)


def anchors(text):
    tokens = parser().parse(text)
    result = set()
    used = set()
    for i, token in enumerate(tokens):
        if token.type != "heading_open":
            continue
        inline = tokens[i + 1]
        title = "".join(t.content for t in inline.children or [] if t.type in {"text", "code_inline"})
        slug = "".join(c for c in html.unescape(title).lower()
                       if c in "-_ " or unicodedata.category(c)[0] in "LNM").replace(" ", "-")
        candidate = slug
        n = 0
        while candidate in used:
            n += 1
            candidate = f"{slug}-{n}"
        used.add(candidate)
        result.add(candidate)
    for token in tokens:
        if token.type in {"html_block", "html_inline"}:
            result.update(re.findall(r'\b(?:id|name)=[\"\']([^\"\']+)', token.content))
        for child in token.children or []:
            if child.type == "html_inline":
                result.update(re.findall(r'\b(?:id|name)=[\"\']([^\"\']+)', child.content))
    return result


def check_links(root, paths, legacy_map):
    root = root.resolve()
    errors = []
    redirects = []
    checked = 0
    anchor_checks = 0
    anchor_cache = {}
    for path in sorted(paths):
        path = path.resolve()
        text = path.read_text(encoding="utf-8")
        for start, end in destination_spans(text):
            raw = html.unescape(text[start:end])
            if not raw or external(raw):
                continue
            # Build-tool script/module entry points (e.g. a Vite
            # <script type="module" src="/src/main.tsx">) are application code,
            # not documentation link targets; do not treat them as doc links.
            if urlsplit(raw).path.rsplit(".", 1)[-1].lower() in {
                    "tsx", "ts", "jsx", "js", "mjs", "cjs"}:
                continue
            checked += 1
            parsed = urlsplit(raw)
            name = unquote(parsed.path).replace("\\", "")
            dest = (root / name.lstrip("/") if name.startswith("/") else path.parent / name).resolve() if name else path.resolve()
            location = f"{path.relative_to(root)}:{text.count(chr(10), 0, start) + 1} -> {raw}"
            if not dest.is_relative_to(root):
                errors.append(f"outside repository: {location}")
                continue
            rel = dest.relative_to(root).as_posix()
            if not dest.exists():
                errors.append(f"missing file: {location}")
                continue
            if rel in legacy_map:
                redirects.append({"source": str(path.relative_to(root)), "legacy_path": rel,
                                  "canonical_path": legacy_map[rel], "fragment": unquote(parsed.fragment)})
            if parsed.fragment and dest.is_file() and (dest.suffix.lower() in {".md", ".html"} or dest.name == "LICENSE"):
                anchor_checks += 1
                if dest not in anchor_cache:
                    anchor_cache[dest] = anchors(dest.read_text(encoding="utf-8"))
                fragment = unquote(parsed.fragment)
                if fragment not in anchor_cache[dest]:
                    errors.append(f"missing anchor #{fragment}: {location}")
    return {"files_checked": len(paths), "local_links_checked": checked,
            "anchors_checked": anchor_checks, "errors": errors, "legacy_redirects": redirects}

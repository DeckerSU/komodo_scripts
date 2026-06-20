#!/usr/bin/env python3
"""Verify that every KDF API artifact referenced by the SDK build_config is
actually available from the configured sources, with a matching SHA256 checksum.

This script re-implements, in Python, the exact artifact-resolution logic used by
the Dart build transformer
(`sdk/packages/komodo_wallet_build_transformer/.../fetch_defi_api_build_step.dart`
and the `GithubArtefactDownloader` / `DevBuildsArtefactDownloader` classes):

  * It reads `api.platforms` from the SDK `build_config.json`.
  * For every platform it walks `api.source_urls` in order and resolves the
    artifact whose file name matches the platform `matching_pattern` AND contains
    the configured commit hash (full or 7-char short form), preferring entries
    according to `matching_preference`.
      - For GitHub sources it lists releases and confirms the release tag
        resolves to `api_commit_hash` via the `/commits/{tag}` endpoint.
      - For dev-build sources it scrapes the directory HTML listings
        (`/{branch}/`, `/{sanitized-branch}/`, `/`) and skips names containing
        "wallet".
  * It downloads the resolved artifact (with a live progress bar) and compares
    its SHA256 against `valid_zip_sha256_checksums`.

Goal / reporting:
  * If a source yields the expected checksum, the platform is considered OK and
    we move on (this mirrors the transformer, which stops at the first source
    that validates).
  * If a source yields a pattern-matching artifact whose checksum does NOT match,
    we keep the source, file name and the actual checksum, then keep probing the
    remaining sources. The final report makes clear that "we were looking for
    checksum X but the sources only offer these other artifacts (with these
    checksums)".
  * Artifacts that match the pattern but belong to a different commit are listed
    too, so it is obvious which builds the sources actually carry.

The GitHub token is taken from the GITHUB_API_PUBLIC_READONLY_TOKEN environment
variable (optional, but recommended to avoid rate limiting).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import posixpath
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from html.parser import HTMLParser
from typing import Dict, Iterable, List, Optional, Tuple

# --------------------------------------------------------------------------- #
# Constants
# --------------------------------------------------------------------------- #

GITHUB_API_PREFIX = "https://api.github.com/repos/"
GITHUB_TOKEN_ENV = "GITHUB_API_PUBLIC_READONLY_TOKEN"

# Path to the build_config.json relative to the repository root. This is the file
# the transformer actually consumes (the sibling build_config.yaml is unused).
DEFAULT_BUILD_CONFIG = os.path.join(
    "sdk",
    "packages",
    "komodo_defi_framework",
    "app_build",
    "build_config.json",
)

USER_AGENT = "verify-kdf-artifacts/1.0"
HTTP_TIMEOUT = 60  # seconds


# --------------------------------------------------------------------------- #
# Tiny ANSI helpers (no external dependencies)
# --------------------------------------------------------------------------- #

class C:
    _enabled = sys.stdout.isatty()

    @classmethod
    def wrap(cls, code: str, text: str) -> str:
        if not cls._enabled:
            return text
        return f"\033[{code}m{text}\033[0m"


def green(t: str) -> str:
    return C.wrap("32", t)


def red(t: str) -> str:
    return C.wrap("31", t)


def yellow(t: str) -> str:
    return C.wrap("33", t)


def cyan(t: str) -> str:
    return C.wrap("36", t)


def bold(t: str) -> str:
    return C.wrap("1", t)


def dim(t: str) -> str:
    return C.wrap("2", t)


# --------------------------------------------------------------------------- #
# Matching config (mirrors ApiFileMatchingConfig)
# --------------------------------------------------------------------------- #

class MatchingConfig:
    def __init__(
        self,
        pattern: Optional[str],
        keyword: Optional[str],
        preference: List[str],
    ) -> None:
        self.pattern = pattern
        self.keyword = keyword
        self.preference = preference
        self._regex = re.compile(pattern) if pattern else None

    def matches(self, name: str) -> bool:
        if self._regex is not None:
            return self._regex.search(name) is not None
        if self.keyword is not None:
            return self.keyword in name
        return False

    def choose_preferred(self, candidates: List[str]) -> Optional[str]:
        """Return the best candidate file name according to `preference`.

        Earlier preference items win; if nothing matches, the first candidate is
        returned (mirrors the Dart `choosePreferred`)."""
        if not candidates:
            return None
        if not self.preference:
            return candidates[0]
        for pref in self.preference:
            for c in candidates:
                if pref in c:
                    return c
        return candidates[0]

    def describe(self) -> str:
        if self.pattern:
            return f"pattern={self.pattern!r}"
        return f"keyword={self.keyword!r}"


# --------------------------------------------------------------------------- #
# Data classes
# --------------------------------------------------------------------------- #

class Candidate:
    """A file matching the platform pattern that was found on a source."""

    def __init__(self, name: str, url: str, source: str, commit_matches: bool):
        self.name = name
        self.url = url
        self.source = source
        # True when the file name carries the configured commit hash (full/short).
        self.commit_matches = commit_matches
        self.sha256: Optional[str] = None  # populated after download


class PlatformResult:
    def __init__(self, platform: str, expected: List[str]):
        self.platform = platform
        self.expected = expected
        self.ok = False
        self.matched_source: Optional[str] = None
        self.matched_name: Optional[str] = None
        # All distinct (name, url, source, sha) artifacts we downloaded.
        self.downloaded: List[Candidate] = []
        # Pattern-matching files that belong to a different commit (not probed).
        self.other_builds: List[Candidate] = []
        self.errors: List[str] = []


# --------------------------------------------------------------------------- #
# HTTP utilities
# --------------------------------------------------------------------------- #

def _request(url: str, headers: Dict[str, str]) -> urllib.request.Request:
    h = {"User-Agent": USER_AGENT}
    h.update(headers)
    return urllib.request.Request(url, headers=h)


def http_get_text(url: str, headers: Optional[Dict[str, str]] = None) -> Tuple[int, str]:
    req = _request(url, headers or {})
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
            return resp.getcode(), resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", errors="replace")


def http_get_json(url: str, headers: Optional[Dict[str, str]] = None):
    code, body = http_get_text(url, headers)
    if code != 200:
        raise RuntimeError(f"HTTP {code} for {url}: {body[:200]}")
    return json.loads(body)


def format_bytes(n: float) -> str:
    for unit in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unit == "GiB":
            return f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} GiB"


def download_with_progress(
    url: str,
    headers: Optional[Dict[str, str]] = None,
) -> Tuple[str, int]:
    """Download `url` to memory, print a progress bar, and return its SHA256.

    Returns (sha256_hex, total_bytes)."""
    req = _request(url, headers or {})
    sha = hashlib.sha256()
    total = 0
    downloaded = 0
    start = time.time()
    label = posixpath.basename(urllib.parse.urlparse(url).path) or url

    with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
        length_header = resp.headers.get("Content-Length")
        total = int(length_header) if length_header and length_header.isdigit() else 0
        chunk_size = 64 * 1024
        last_render = 0.0
        while True:
            chunk = resp.read(chunk_size)
            if not chunk:
                break
            sha.update(chunk)
            downloaded += len(chunk)
            now = time.time()
            if now - last_render >= 0.1 or (total and downloaded >= total):
                last_render = now
                _render_progress(label, downloaded, total, now - start)
    _render_progress(label, downloaded, total or downloaded, time.time() - start)
    sys.stdout.write("\n")
    sys.stdout.flush()
    return sha.hexdigest(), downloaded


def _render_progress(label: str, done: int, total: int, elapsed: float) -> None:
    if not sys.stdout.isatty():
        return
    speed = done / elapsed if elapsed > 0 else 0
    if total > 0:
        frac = min(done / total, 1.0)
        width = 28
        filled = int(width * frac)
        bar = "#" * filled + "-" * (width - filled)
        msg = (
            f"\r    [{bar}] {frac * 100:5.1f}%  "
            f"{format_bytes(done)}/{format_bytes(total)}  "
            f"{format_bytes(speed)}/s  {label[:40]}"
        )
    else:
        msg = (
            f"\r    {format_bytes(done)} downloaded  "
            f"{format_bytes(speed)}/s  {label[:40]}"
        )
    sys.stdout.write(msg[:140].ljust(0))
    sys.stdout.flush()


# --------------------------------------------------------------------------- #
# GitHub source resolution (mirrors GithubArtefactDownloader.fetchDownloadUrl)
# --------------------------------------------------------------------------- #

class GithubSource:
    def __init__(self, base_url: str, branch: str, commit_hash: str, token: Optional[str]):
        self.base_url = base_url.rstrip("/")
        self.branch = branch
        self.commit_hash = commit_hash
        self.short_hash = commit_hash[:7]
        self.headers = {"Accept": "application/vnd.github.v3+json"}
        if token:
            self.headers["Authorization"] = f"Bearer {token}"
        self._releases_cache: Optional[List[dict]] = None
        self._commit_cache: Dict[str, Optional[str]] = {}

    def _get_releases(self) -> List[dict]:
        if self._releases_cache is not None:
            return self._releases_cache
        releases: List[dict] = []
        page = 1
        # The transformer fetches a single page; we paginate so verification is
        # complete even when there are many releases. Matching semantics are
        # unchanged.
        while True:
            url = f"{self.base_url}/releases?per_page=100&page={page}"
            batch = http_get_json(url, self.headers)
            if not isinstance(batch, list) or not batch:
                break
            releases.extend(batch)
            if len(batch) < 100:
                break
            page += 1
            if page > 20:  # safety cap
                break
        self._releases_cache = releases
        return releases

    def _commit_for_tag(self, tag: str) -> Optional[str]:
        if tag in self._commit_cache:
            return self._commit_cache[tag]
        url = f"{self.base_url}/commits/{urllib.parse.quote(tag, safe='')}"
        try:
            data = http_get_json(url, self.headers)
            sha = data.get("sha") if isinstance(data, dict) else None
        except Exception:
            sha = None
        self._commit_cache[tag] = sha
        return sha

    def find_candidates(self, mc: MatchingConfig) -> Tuple[List[Candidate], List[Candidate]]:
        """Return (commit_matching_candidates, other_pattern_matches).

        `commit_matching_candidates` are files whose name matches the pattern,
        carry the configured commit hash, and whose release tag resolves to that
        same commit (full transformer logic). `other_pattern_matches` are
        pattern matches that do not satisfy the commit checks (informational)."""
        matching: List[Candidate] = []
        others: List[Candidate] = []
        releases = self._get_releases()
        for release in releases:
            tag = release.get("tag_name", "")
            for asset in release.get("assets", []):
                dl = asset.get("browser_download_url", "")
                name = posixpath.basename(urllib.parse.urlparse(dl).path)
                if not mc.matches(name):
                    continue
                has_hash = (self.commit_hash in name) or (self.short_hash in name)
                if has_hash and self._commit_for_tag(tag) == self.commit_hash:
                    matching.append(Candidate(name, dl, self.base_url, True))
                else:
                    others.append(Candidate(name, dl, self.base_url, False))
        return matching, others


# --------------------------------------------------------------------------- #
# Dev-builds source resolution (mirrors DevBuildsArtefactDownloader)
# --------------------------------------------------------------------------- #

class _AnchorParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.hrefs: List[str] = []

    def handle_starttag(self, tag, attrs):
        if tag.lower() != "a":
            return
        for k, v in attrs:
            if k.lower() == "href" and v:
                self.hrefs.append(v)


class DevBuildsSource:
    def __init__(self, source_url: str, branch: str, commit_hash: str):
        self.source_url = source_url
        self.branch = branch
        self.commit_hash = commit_hash
        self.short_hash = commit_hash[:7]

    def _listing_urls(self) -> List[str]:
        normalized = self.source_url if self.source_url.endswith("/") else self.source_url + "/"
        sanitized = self.branch.replace("/", "-")
        urls: List[str] = []
        seen = set()

        def add(u: str) -> None:
            if u not in seen:
                seen.add(u)
                urls.append(u)

        if self.branch:
            add(urllib.parse.urljoin(normalized, f"{self.branch}/"))
        if self.branch and sanitized != self.branch:
            add(urllib.parse.urljoin(normalized, f"{sanitized}/"))
        add(normalized)
        return urls

    def find_candidates(self, mc: MatchingConfig) -> Tuple[List[Candidate], List[Candidate]]:
        matching: List[Candidate] = []
        others: List[Candidate] = []
        seen_names = set()
        for listing in self._listing_urls():
            try:
                code, body = http_get_text(listing)
                if code != 200:
                    continue
            except Exception:
                continue
            parser = _AnchorParser()
            parser.feed(body)
            for href in parser.hrefs:
                href_path = urllib.parse.urlparse(href).path or href
                name = posixpath.basename(href_path)
                if not name:
                    continue
                # Ignore wallet archives on the Nebula index (transformer parity).
                if "wallet" in name:
                    continue
                if not (mc.matches(name) and href_path.endswith(".zip")):
                    continue
                resolved = href if href.startswith("http") else urllib.parse.urljoin(listing, href)
                has_hash = (self.commit_hash in href_path) or (self.short_hash in href_path)
                key = (name, resolved)
                if key in seen_names:
                    continue
                seen_names.add(key)
                cand = Candidate(name, resolved, self.source_url, has_hash)
                if has_hash:
                    matching.append(cand)
                else:
                    others.append(cand)
        return matching, others


# --------------------------------------------------------------------------- #
# Core verification
# --------------------------------------------------------------------------- #

def build_source_resolver(source_url: str, branch: str, commit_hash: str, token: Optional[str]):
    if source_url.startswith(GITHUB_API_PREFIX):
        return GithubSource(source_url, branch, commit_hash, token)
    return DevBuildsSource(source_url, branch, commit_hash)


def verify_platform(
    platform: str,
    pcfg: dict,
    source_urls: List[str],
    branch: str,
    commit_hash: str,
    token: Optional[str],
) -> PlatformResult:
    expected = list(pcfg.get("valid_zip_sha256_checksums", []))
    mc = MatchingConfig(
        pattern=pcfg.get("matching_pattern"),
        keyword=pcfg.get("matching_keyword"),
        preference=list(pcfg.get("matching_preference", []) or []),
    )
    result = PlatformResult(platform, expected)

    print()
    print(bold(f"=== Platform: {cyan(platform)} ==="))
    print(f"  {mc.describe()}")
    print(f"  expected sha256: {', '.join(yellow(c) for c in expected) or red('<none>')}")

    downloaded_urls: Dict[str, str] = {}  # url -> sha256 (avoid re-downloading)

    for source_url in source_urls:
        resolver = build_source_resolver(source_url, branch, commit_hash, token)
        kind = "github" if isinstance(resolver, GithubSource) else "dev-builds"
        print(f"\n  {dim('source')} {source_url} ({kind})")
        try:
            matching, others = resolver.find_candidates(mc)
        except Exception as e:
            msg = f"failed to query source {source_url}: {e}"
            result.errors.append(msg)
            print(f"    {red('!')} {msg}")
            continue

        for o in others:
            if all(o.name != x.name for x in result.other_builds):
                result.other_builds.append(o)

        if not matching:
            print(f"    {yellow('-')} no artifact matching the configured commit "
                  f"({commit_hash[:7]}) found here")
            if others:
                print(f"      {dim('(other pattern matches present: ' + ', '.join(sorted({o.name for o in others}))[:200] + ')')}")
            continue

        # Pick the preferred candidate exactly like the transformer.
        names = [c.name for c in matching]
        preferred_name = mc.choose_preferred(names)
        candidate = next(c for c in matching if c.name == preferred_name)
        print(f"    {green('+')} found: {candidate.name}")
        if len(matching) > 1:
            print(f"      {dim('(also matched: ' + ', '.join(n for n in names if n != preferred_name) + ')')}")

        # Download (or reuse) and checksum.
        if candidate.url in downloaded_urls:
            sha = downloaded_urls[candidate.url]
            print(f"      {dim('(already downloaded)')} sha256 = {sha}")
        else:
            try:
                headers = resolver.headers if isinstance(resolver, GithubSource) else None
                print(f"      downloading {candidate.url}")
                sha, size = download_with_progress(candidate.url, headers)
                downloaded_urls[candidate.url] = sha
                print(f"      size: {format_bytes(size)}  sha256: {sha}")
            except Exception as e:
                msg = f"download failed from {source_url}: {e}"
                result.errors.append(msg)
                print(f"      {red('!')} {msg}")
                continue

        candidate.sha256 = sha
        result.downloaded.append(candidate)

        if sha in expected:
            print(f"      {green('OK')} checksum matches expected value")
            result.ok = True
            result.matched_source = source_url
            result.matched_name = candidate.name
            break  # transformer stops at the first validating source
        else:
            print(f"      {red('MISMATCH')} expected one of "
                  f"{expected}, got {sha}")

    # Per-platform summary line.
    if result.ok:
        print(f"\n  {green('PASS')} {platform}: {result.matched_name} from "
              f"{result.matched_source}")
    else:
        print(f"\n  {red('FAIL')} {platform}: no source provided an artifact with "
              f"the expected checksum")
    return result


def load_build_config(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify KDF API artifacts referenced by the SDK build_config "
                    "are available from the configured sources with matching checksums.",
    )
    parser.add_argument(
        "--config",
        default=DEFAULT_BUILD_CONFIG,
        help=f"Path to build_config.json (default: {DEFAULT_BUILD_CONFIG})",
    )
    parser.add_argument(
        "--platform",
        action="append",
        help="Restrict verification to the given platform(s). Repeatable.",
    )
    args = parser.parse_args()

    config_path = args.config
    if not os.path.isabs(config_path) and not os.path.exists(config_path):
        # Try resolving relative to the repository root (two levels up from here).
        here = os.path.dirname(os.path.abspath(__file__))
        candidate = os.path.join(os.path.dirname(here), config_path)
        if os.path.exists(candidate):
            config_path = candidate

    if not os.path.exists(config_path):
        print(red(f"build_config not found: {config_path}"), file=sys.stderr)
        return 2

    token = os.environ.get(GITHUB_TOKEN_ENV) or None
    print(bold("KDF artifact verification"))
    print(f"  config: {config_path}")
    print(f"  github token: {green('present') if token else yellow('absent (unauthenticated, may hit rate limits)')}")

    cfg = load_build_config(config_path)
    api = cfg.get("api", {})
    commit_hash = api.get("api_commit_hash", "")
    branch = api.get("branch", "")
    source_urls = list(api.get("source_urls", []))
    platforms = api.get("platforms", {})

    print(f"  commit: {commit_hash}")
    print(f"  branch: {branch}")
    print(f"  sources: {source_urls}")

    if not commit_hash or not source_urls or not platforms:
        print(red("build_config.api is missing api_commit_hash, source_urls or platforms"),
              file=sys.stderr)
        return 2

    selected = args.platform
    results: List[PlatformResult] = []
    for name, pcfg in platforms.items():
        if selected and name not in selected:
            continue
        results.append(
            verify_platform(name, pcfg, source_urls, branch, commit_hash, token)
        )

    # --------------------------------------------------------------------- #
    # Final report
    # --------------------------------------------------------------------- #
    print()
    print(bold("================ SUMMARY ================"))
    passed = [r for r in results if r.ok]
    failed = [r for r in results if not r.ok]

    for r in results:
        status = green("PASS") if r.ok else red("FAIL")
        print(f"  {status}  {r.platform}")
        if r.ok:
            continue
        print(f"        looking for: {', '.join(r.expected)}")
        if r.downloaded:
            print(f"        but the sources offer (same commit, different content):")
            for c in r.downloaded:
                print(f"          - {c.name}  sha256={c.sha256}  [{c.source}]")
        if r.other_builds:
            uniq = sorted({c.name for c in r.other_builds})
            print(f"        other pattern-matching artifacts present (different commit), not checksummed:")
            for n in uniq:
                print(f"          - {n}")
        if not r.downloaded and not r.other_builds:
            print(f"        {yellow('no artifact matching the pattern was found on any source')}")
        for err in r.errors:
            print(f"        {dim('note: ' + err)}")

    print()
    print(f"  {green(str(len(passed)) + ' passed')}, "
          f"{red(str(len(failed)) + ' failed')} "
          f"of {len(results)} platform(s)")

    return 0 if not failed else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(130)

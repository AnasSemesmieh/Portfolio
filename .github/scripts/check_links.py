"""Fail if an internal href/src in tracked html, or a sitemap URL, has no file."""
import re, subprocess, sys
from pathlib import Path
from urllib.parse import urlparse, unquote

root = Path(".").resolve()
files = subprocess.check_output(["git", "ls-files", "*.html"], text=True).split()

def exists(path):
    p = root / unquote(path).lstrip("/")
    return p.is_file() or (p / "index.html").is_file() or p.with_suffix(".html").is_file()

bad = []
for f in files:
    for ref in re.findall(r'(?:href|src)="([^"]+)"', Path(f).read_text(errors="ignore")):
        u = urlparse(ref)
        if u.scheme or u.netloc or not u.path or ref.startswith(("#", "mailto:", "tel:", "data:")) or "${" in ref:
            continue
        path = u.path if u.path.startswith("/") else str(Path(f).parent / u.path)
        if not exists(path):
            bad.append(f"{f}: {ref}")
for loc in re.findall(r"<loc>([^<]+)</loc>", Path("sitemap.xml").read_text()):
    if not exists(urlparse(loc).path):
        bad.append(f"sitemap.xml: {loc}")
print("\n".join(bad) or "links ok")
sys.exit(1 if bad else 0)

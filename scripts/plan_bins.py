#!/usr/bin/env python3
"""Group repack files (fg-*.bin) into N balanced groups -> GitHub matrix JSON.

stdin : the raw `files` workflow input; lines are either
          <name>|<url>           (explicit name; URL may be any direct link)
          <url>                  (name taken from the URL's last segment)
env   : GROUPS (int), GITHUB_OUTPUT
stdout: matrix={"include":[{"i":k,"urls":"name1|url1,name2|url2"},...]}
"""
import json, os, sys
from urllib.parse import urlparse

GROUPS = max(1, int(os.environ.get("GROUPS", "2")))

small, bins = [], []
for raw in sys.stdin.read().splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    if "|" in line:
        name, url = line.split("|", 1)
        name = name.strip()
    else:
        url = line
        name = os.path.basename(urlparse(url).path)
    if not name:
        print(f"::error::cannot derive a file name from line: {line}", file=sys.stderr)
        sys.exit(1)
    entry = {"name": name, "url": url}
    if name.lower().endswith(".bin") and name.lower().startswith("fg-"):
        bins.append(entry)
    else:
        small.append(entry)

if not bins:
    print("::error::no fg-*.bin lines found in the pasted file list", file=sys.stderr)
    sys.exit(1)

bins.sort(key=lambda e: e["name"].lower())
out = [[] for _ in range(GROUPS)]
for idx, entry in enumerate(bins):          # round-robin = roughly balanced
    out[idx % GROUPS].append(entry)

matrix = {"include": [
    {"i": k,
     "urls": ",".join(f"{x['name']}|{x['url']}" for x in grp),
     "smalls": json.dumps(small)}
    for k, grp in enumerate(out) if grp
]}

with open(os.environ["GITHUB_OUTPUT"], "a") as fh:
    fh.write(f"matrix={json.dumps(matrix)}\n")
    fh.write(f"ngroups={sum(1 for g in out if g)}\n")

print(f"planned {len(bins)} bins + {len(small)} small files into "
      f"{sum(1 for g in out if g)} groups", file=sys.stderr)

# fg-unpacker

Extract FitGirl-style repacks in GitHub Actions (free Linux runners) and get back a
pre-extracted, store-mode zip — so nobody ever burns a night on the installer again.

**The engine does the hard part already:** this project is a thin orchestrator around
[pisek/fitgirl-extractor](https://github.com/pisek/fitgirl-extractor) (embedded
`innoextract` + Wine-driven `unarc.dll`, MD5-verified output). We add: GitHub-hosted
scheduling, parallel bin slices, and GoFile upload of results.

> Personal use, private repo. Everything here is generic archiving automation;
> no game content is included (and CI never commits any).

## Architecture

```
[You: copy the repack's direct file URLs (setup.exe + fg-*.bin + MD5 manifests)]
        │  pasted into the workflow dispatch form
        ▼
ubuntu-latest GH runner (~85GB free after disk-expand trick)
  smoke job : engine + Wine sanity check (no game content involved)
  plan job  : read pasted URLs -> split fg-*.bin into N balanced groups
  unpack jobs (matrix, one group per job):
                1. download only this group's bins + the small files
                2. extract: innoextract (native) + Wine for the closed-source codecs
                3. 7z store-mode zip (-tzip -mx=0) → re-unpacks in minutes later
                4. upload zip to GoFile as GUEST (no account!) → public downloadPage links
[You: open links from the job summary, download the N zips, unzip into one folder]
```

## The GoFile direction truth (verified live, Nov 2026)

| Direction | Account needed? | Why |
|---|---|---|
| **Upload** (CI → GoFile) | **No** — guest token minted per run (`POST /accounts`) | Each part gets its own public `downloadPage` link |
| **Download** (CI ← GoFile) | **Yes… and worse**: programmatic listing/direct-link access returned `error-notPremium` even *with* the uploader's own token | GoFile's API now gates listing to premium; their direct-download URLs serve an HTML page, not the file |

Conclusion: GoFile = **results out** (perfect for your use case), never results in.
CI therefore takes the repack's original download URLs directly as a pasted list —
which is what you already have anyway when you grab a repack.

## Why this beats the 6-hour limit

FitGirl repacks ship **several independent `fg-*.bin` FreeArc solid archives**.
Solid = sequential *within* one bin, but bins are independent of each other.
So instead of one 8-hour job, `plan` splits the bins into groups and the
matrix runs one group per job — wall clock = slowest group, each job < ~6h
(workflow also caps at 355 min as a safety net). Re-running one failed group
re-runs only that group.

The outputs need no reassembly: `group-0.zip`, `group-1.zip`, … — extract them
all into the same folder and you have the full game.

## How to use

1. **Create the repo** (private) and push this folder.
2. Run the `unpack` workflow with:
   - `file_list`: one `<name>|<url>` per line (or bare URL; name = basename) for
     setup.exe, every fg-*.bin, and the MD5 manifest files of your repack.
   - `groups`: 2–4 (bins are often lopsided; round-robin keeps it sane).
   - `zip_split_gb` (optional).
3. Optional secret `SOURCE_TOKEN` if your source links need a cookie/token query.
4. Collect `downloadPage` links from the job summary.

## Honest limits / notes

| Topic | Note |
|---|---|
| Disk | A job holds its group's bins + extracted slice + zip: the largest group must fit in ~80GB free (GitHub free Ubuntu runner + `easimon/maximize-build-space`) |
| Time | 6h cap per job; split into more groups if a slice risks the cap |
| Minutes billing | **Private** repos burn billed Actions minutes after the monthly 2,000 free (Linux = x1 multiplier). Public repos are unlimited-free but anything visible/sharable must stay generic — engines/tools only, no content |
| GoFile ToS | Storage isn't yours; copyrighted uploads can be flagged/removed. Keep it to your own files |
| Wine | Uses distro Wine + i386 WoW64 libs via apt (`wine`,`wine32`,`wine64`); the engine's tested path is Heroic's Wine-11.18 — if the runner's Wine build chokes, pin a newer WoW64 build |
| Engine path | `unarc.dll` is ANSI-only: paths must be Windows-1252 safe (ascii folder names) |
| Post-install | Engine skips `_Redist` runtime installs and registry tweaks — you get the raw games dataset, which is exactly what we want |
| Concurrency | Free tier allows 20 parallel jobs — `max-parallel: 6` is already generous |

## Files

- `.github/workflows/unpack.yml` — the pipeline (smoke + plan + matrix unpack)
- `scripts/gofilectl.sh` — GoFile upload-direction helpers: `upload`, `guest`, `server`
- `scripts/plan_bins.py` — group `fg-*.bin` URLs into N balanced groups → matrix JSON

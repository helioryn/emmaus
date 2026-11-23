#!/usr/bin/env python3
"""Download public-domain / CC commentary chapters from the Free Use Bible API."""
import json, os, sys, time, urllib.request, concurrent.futures
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "raw" / "commentaries"
OUT.mkdir(parents=True, exist_ok=True)
WORKS = ["matthew-henry", "jamieson-fausset-brown", "tyndale", "geneva", "scofield"]
BASE = "https://bible.helloao.org/api/c"

def get(url, tries=4):
    for i in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=45) as r:
                return json.load(r)
        except Exception as e:
            if i == tries-1:
                return None
            time.sleep(1.5*(i+1))

def main():
    jobs = []
    for work in WORKS:
        d = get(f"{BASE}/{work}/books.json")
        if not d:
            print("FAILED books", work, flush=True)
            continue
        for b in d.get("books", []):
            bid = b["id"]
            nch = b.get("numberOfChapters", 0)
            (OUT/work).mkdir(parents=True, exist_ok=True)
            for ch in range(1, nch+1):
                path = OUT/work/f"{bid}-{ch}.json"
                if path.exists() and path.stat().st_size > 100:
                    continue
                jobs.append((work, bid, ch, path))
    print("jobs", len(jobs), flush=True)
    done = 0
    def fetch(job):
        work, bid, ch, path = job
        d = get(f"{BASE}/{work}/{bid}/{ch}.json")
        if not d or "chapter" not in d:
            return (False, str(path))
        path.write_text(json.dumps(d, ensure_ascii=False), encoding="utf-8")
        return (True, str(path))
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as ex:
        for ok, p in ex.map(fetch, jobs):
            done += 1
            if done % 100 == 0:
                print("done", done, flush=True)
            if not ok:
                print("fail", p, flush=True)
    print("FINISHED", flush=True)

if __name__ == "__main__":
    main()

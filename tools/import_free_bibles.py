#!/usr/bin/env python3
"""Append public-domain / free-licence Bibles from eBible.org to Resources/bible.db.

Verse text only (no Strong's, no red letters, no FTS entries). Re-runnable:
translations that already have verses in the DB are skipped.
"""
import html
import io
import json
import re
import shutil
import sqlite3
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "Resources" / "bible.db"
CACHE = ROOT / "data" / "raw" / "ebible"
CACHE.mkdir(parents=True, exist_ok=True)

# code, eBible id, name, short, language, lang_code, year, license, direction, sort
TRANS = [
    ("BBE",  "engBBE",     "Bible in Basic English",              "BBE",  "English",     "en", "1949", "Public domain", "ltr", 100),
    ("DBY",  "engDBY",     "Darby Translation",                   "DBY",  "English",     "en", "1890", "Public domain", "ltr", 101),
    ("DRA",  "engDRA",     "Douay-Rheims 1899",                   "DRA",  "English",     "en", "1899", "Public domain", "ltr", 102),
    ("GNV",  "enggnv",     "Geneva Bible 1599",                   "GNV",  "English",     "en", "1599", "Public domain", "ltr", 103),
    ("MSB",  "engmsb",     "Majority Standard Bible",             "MSB",  "English",     "en", "2023", "Public domain", "ltr", 104),
    ("RV",   "eng-rv",     "Revised Version 1885",                "RV",   "English",     "en", "1885", "Public domain", "ltr", 105),
    ("WBT",  "engwebster", "Webster Bible",                       "WBT",  "English",     "en", "1833", "Public domain", "ltr", 106),
    ("WMB",  "engwmb",     "World Messianic Bible",               "WMB",  "English",     "en", "2023", "Public domain", "ltr", 107),

    ("CUVS", "cmn-cu89s",  "Chinese Union Version (Simplified)",  "和合本·简", "Chinese", "zh", "1919", "Public domain", "ltr", 120),
    ("CUVT", "cmn-cu89t",  "Chinese Union Version (Traditional)", "和合本·繁", "Chinese", "zh", "1919", "Public domain", "ltr", 121),

    ("RVR",  "spaRV1909",  "Reina Valera 1909",                   "RV1909", "Spanish",   "es", "1909", "Public domain", "ltr", 130),
    ("LSG",  "fraLSG",     "Louis Segond 1910",                   "LSG",  "French",      "fr", "1910", "Public domain", "ltr", 131),
    ("LUT",  "deu1912",    "Luther Bible 1912",                   "LUT",  "German",      "de", "1912", "Public domain", "ltr", 132),
    ("VFL",  "porbrbsl",   "World Portuguese Bible",              "VFL",  "Portuguese",  "pt", "2010", "Public domain", "ltr", 133),
    ("RIV",  "ita1927",    "Riveduta 1927",                       "RIV",  "Italian",     "it", "1927", "Public domain", "ltr", 134),
    ("SYN",  "russyn",     "Russian Synodal Bible",               "SYN",  "Russian",     "ru", "1876", "Public domain", "ltr", 135),
    ("HSV",  "nld",        "Dutch Bible 1917",                    "HSV",  "Dutch",       "nl", "1917", "Public domain", "ltr", 136),
    ("KOR",  "kor",        "Korean Bible 1910",                   "한국",  "Korean",      "ko", "1910", "Public domain", "ltr", 137),
    ("JPB",  "jpnm",       "Japanese Freedom Bible",              "自由",  "Japanese",    "ja", "2020", "Public domain", "ltr", 138),
    ("VIE",  "vie1934",    "Vietnamese Bible 1923",               "VIE",  "Vietnamese",  "vi", "1923", "Public domain", "ltr", 139),
    ("THA",  "thafb",      "Thai Freedom Bible",                  "THA",  "Thai",        "th", "2019", "Public domain", "ltr", 140),
    ("UKR",  "ukr1871",    "Ukrainian Bible (Kulish)",            "UKR",  "Ukrainian",   "uk", "1871", "Public domain", "ltr", 141),
    ("RON",  "ron1924",    "Romanian Bible 1924",                 "RON",  "Romanian",    "ro", "1924", "Public domain", "ltr", 142),
    ("CEP",  "ces1613",    "Czech Kralická Bible 1613",           "CEP",  "Czech",       "cs", "1613", "Public domain", "ltr", 143),
    ("SRP",  "srp1868",    "Serbian Bible 1868",                  "SRP",  "Serbian",     "sr", "1868", "Public domain", "ltr", 144),
    ("MYA",  "mya",        "Burmese Common Language Bible",       "MYA",  "Burmese",     "my", "2005", "Public domain", "ltr", 145),
    ("EPO",  "epo",        "Esperanto Bible",                     "EPO",  "Esperanto",   "eo", "1926", "Public domain", "ltr", 146),
    ("HAW",  "haw1868",    "Hawaiian Bible 1868",                 "HAW",  "Hawaiian",    "haw", "1868", "Public domain", "ltr", 147),
    ("HAT",  "hat",        "Haitian Creole Bible 1985",           "HAT",  "Haitian",     "ht", "1985", "Public domain", "ltr", 148),
    ("PES",  "pesOPV",     "Old Persian Version Bible",           "PES",  "Persian",     "fa", "1895", "Public domain", "rtl", 149),
]

USFM_CODES = {
    "GEN":0,"EXO":1,"LEV":2,"NUM":3,"DEU":4,"JOS":5,"JDG":6,"RUT":7,"1SA":8,"2SA":9,
    "1KI":10,"2KI":11,"1CH":12,"2CH":13,"EZR":14,"NEH":15,"EST":16,"JOB":17,"PSA":18,
    "PRO":19,"ECC":20,"SNG":21,"ISA":22,"JER":23,"LAM":24,"EZK":25,"DAN":26,"HOS":27,
    "JOL":28,"AMO":29,"OBA":30,"JON":31,"MIC":32,"NAM":33,"HAB":34,"ZEP":35,"HAG":36,
    "ZEC":37,"MAL":38,"MAT":39,"MRK":40,"LUK":41,"JHN":42,"ACT":43,"ROM":44,"1CO":45,
    "2CO":46,"GAL":47,"EPH":48,"PHP":49,"COL":50,"1TH":51,"2TH":52,"1TI":53,"2TI":54,
    "TIT":55,"PHM":56,"HEB":57,"JAS":58,"1PE":59,"2PE":60,"1JN":61,"2JN":62,"3JN":63,
    "JUD":64,"REV":65,
}


def log(*a):
    print(*a, flush=True)


def download(tid):
    zpath = CACHE / f"{tid}.usfm.zip"
    if zpath.exists() and zpath.stat().st_size > 100_000:
        return zpath
    url = f"https://ebible.org/Scriptures/{tid}_usfm.zip"
    log("downloading", url)
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36",
        "Referer": "https://ebible.org/Scriptures/",
    })
    with urllib.request.urlopen(req, timeout=300) as r, open(zpath, "wb") as f:
        shutil.copyfileobj(r, f)
    log("  ", zpath.stat().st_size // 1024, "KB")
    return zpath


def strip_markup(s):
    s = re.sub(r"\\f\b.*?\\f\*", "", s, flags=re.S)
    s = re.sub(r"\\x\b.*?\\x\*", "", s, flags=re.S)
    s = re.sub(r"\\fig\b.*?\\fig\*", "", s, flags=re.S)
    s = re.sub(r"\\w\s+([^\\|]*?)\|.*?\\w\*", r"\1", s)
    s = re.sub(r"\\\+?w\s+([^\\|]*?)\\+?w\*", r"\1", s)
    s = re.sub(r"\|[^\\]*", "", s)
    s = re.sub(r"\\[a-zA-Z0-9+\-]+\*?", " ", s)
    s = s.replace("~", " ")
    s = html.unescape(s)
    return re.sub(r"\s+", " ", s).strip()


def parse_usfm(src):
    """Yield (book_index, chapter, verse, text). Accepts bytes, a path, or a binary stream."""
    if isinstance(src, (bytes, bytearray)):
        fh = io.TextIOWrapper(io.BytesIO(src), encoding="utf-8-sig", errors="replace")
    elif hasattr(src, "read"):
        fh = io.TextIOWrapper(src, encoding="utf-8-sig", errors="replace")
    else:
        fh = io.TextIOWrapper(open(src, "rb"), encoding="utf-8-sig", errors="replace")
    book = None
    chapter = 0
    verse = None
    buf = []

    def flush():
        nonlocal verse, buf
        if verse is None:
            return None
        text = strip_markup(" ".join(buf))
        out = (book, chapter, verse, text) if text and book is not None else None
        verse, buf = None, []
        return out

    for raw in fh:
        line = raw.rstrip("\n")
        m = re.match(r"^\\id\s+([A-Z0-9]{3})", line)
        if m:
            book = USFM_CODES.get(m.group(1))
            continue
        m = re.match(r"^\\c\s+(\d+)", line)
        if m:
            r = flush()
            if r:
                yield r
            chapter = int(m.group(1))
            continue
        m = re.match(r"^\\v\s+(\d+)(?:-(\d+))?[a-z]?\s*(.*)$", line)
        if m:
            r = flush()
            if r:
                yield r
            verse = int(m.group(1))
            buf = [m.group(3)]
            continue
        if line.startswith("\\"):
            if line.startswith(("\\s", "\\r", "\\d", "\\p", "\\q", "\\m", "\\b", "\\li",
                                "\\pi", "\\nb", "\\cls", "\\qa", "\\qc", "\\qm", "\\qr",
                                "\\qs", "\\ts", "\\toc", "\\mt", "\\h", "\\ide", "\\rem",
                                "\\sts", "\\cp", "\\ca", "\\cl", "\\vp")):
                continue
            if verse is not None:
                buf.append(line)
            continue
        if verse is not None:
            buf.append(line)
    r = flush()
    if r:
        yield r


def already(con, code):
    n = con.execute("SELECT COUNT(*) FROM verses WHERE translation=?", (code,)).fetchone()[0]
    return n


def main():
    if not DB.exists():
        sys.exit(f"missing {DB}")
    backup = DB.with_suffix(".db.before-free-bibles")
    if not backup.exists():
        log("backing up db ->", backup.name)
        shutil.copy2(DB, backup)

    con = sqlite3.connect(DB)
    con.execute("PRAGMA journal_mode=OFF")
    con.execute("PRAGMA synchronous=OFF")
    con.execute("PRAGMA cache_size=-200000")

    total = 0
    for code, tid, name, short, language, lang_code, year, lic, direction, sort in TRANS:
        have = already(con, code)
        if have:
            log(f"{code:5} already present ({have} verses), skipping")
            continue
        try:
            zpath = download(tid)
            rows = []
            with zipfile.ZipFile(zpath) as z:
                names = [n for n in z.namelist() if n.lower().endswith(".usfm")]
                for n in names:
                    m = re.match(r"^(\d+)-([A-Z0-9]{3})", Path(n).name)
                    if not m or m.group(2) not in USFM_CODES:
                        continue
                    with z.open(n) as fh:
                        data = fh.read()
                    for r in parse_usfm(data):
                        rows.append((code, r[0] + 1, r[1], r[2], r[3], None, 0))
            if not rows:
                log(f"{code:5} FAILED to parse")
                continue
            con.executemany(
                "INSERT OR REPLACE INTO verses(translation,book,chapter,verse,text,tokens,has_red)"
                " VALUES(?,?,?,?,?,?,?)", rows)
            con.execute(
                "INSERT OR REPLACE INTO translations(code,name,short,language,lang_code,year,license,"
                "attribution,has_strongs,has_red,has_interlinear,source,bible_id,sort,direction)"
                " VALUES(?,?,?,?,?,?,?,?,0,0,0,'local',NULL,?,?)",
                (code, name, short, language, lang_code, year, lic,
                 f"{name} — courtesy of eBible.org ({tid}). {lic}.", sort, direction))
            con.commit()
            log(f"{code:5} OK {len(rows):>6} verses  ({name})")
            total += len(rows)
        except Exception as e:  # keep going on a single bad download
            log(f"{code:5} ERROR {e}")
            try:
                (CACHE / f"{tid}.usfm.zip").unlink()
            except OSError:
                pass

    con.execute("UPDATE meta SET value=? WHERE key='built'", ("2026-11-23",))
    con.commit()
    con.close()
    log(f"done: {total} verses added; db = {DB.stat().st_size // (1024*1024)} MB")


if __name__ == "__main__":
    main()

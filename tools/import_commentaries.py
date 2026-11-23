#!/usr/bin/env python3
"""Load downloaded commentary JSON into bible.db."""
import json, sqlite3, re, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "Resources" / "bible.db"
SRC = ROOT / "data" / "raw" / "commentaries"
CODES = {
 "GEN":1,"EXO":2,"LEV":3,"NUM":4,"DEU":5,"JOS":6,"JDG":7,"RUT":8,"1SA":9,"2SA":10,
 "1KI":11,"2KI":12,"1CH":13,"2CH":14,"EZR":15,"NEH":16,"EST":17,"JOB":18,"PSA":19,
 "PRO":20,"ECC":21,"SNG":22,"ISA":23,"JER":24,"LAM":25,"EZK":26,"DAN":27,"HOS":28,
 "JOL":29,"AMO":30,"OBA":31,"JON":32,"MIC":33,"NAM":34,"HAB":35,"ZEP":36,"HAG":37,
 "ZEC":38,"MAL":39,"MAT":40,"MRK":41,"LUK":42,"JHN":43,"ACT":44,"ROM":45,"1CO":46,
 "2CO":47,"GAL":48,"EPH":49,"PHP":50,"COL":51,"1TH":52,"2TH":53,"1TI":54,"2TI":55,
 "TIT":56,"PHM":57,"HEB":58,"JAS":59,"1PE":60,"2PE":61,"1JN":62,"2JN":63,"3JN":64,
 "JUD":65,"REV":66,
}

def extract(node):
    if node is None: return ""
    if isinstance(node, str): return node
    if isinstance(node, list):
        return "".join(extract(x) for x in node)
    if isinstance(node, dict):
        t = node.get("type")
        if t in ("line_break", "paragraph"): return "\n\n"
        if t == "heading": return "\n" + extract(node.get("content")) + "\n"
        return extract(node.get("content"))
    return str(node)

def clean(text):
    text = text.replace("\r", "")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()

def main():
    con = sqlite3.connect(DB)
    c = con.cursor()
    c.execute("DELETE FROM commentaries")
    con.commit()
    total = 0
    t0 = time.time()
    for workdir in sorted(SRC.iterdir()):
        if not workdir.is_dir(): continue
        work = workdir.name
        n = 0
        for path in sorted(workdir.glob("*.json")):
            m = re.match(r"^([A-Z0-9]{3})-(\d+)\.json$", path.name)
            if not m: continue
            bid = CODES.get(m.group(1))
            if not bid: continue
            chn = int(m.group(2))
            try:
                d = json.loads(path.read_text(encoding="utf-8"))
            except Exception:
                continue
            chapter = d.get("chapter", {})
            content = chapter.get("content", [])
            entries = []
            for item in content:
                if not isinstance(item, dict): continue
                v = item.get("number")
                if not isinstance(v, int): continue
                body = clean(extract(item.get("content")))
                if body:
                    entries.append((v, body))
            # last verse number in chapter
            maxv = c.execute("SELECT MAX(verse) FROM verses WHERE translation='KJV' AND book=? AND chapter=?", (bid, chn)).fetchone()[0] or 0
            entries.sort()
            for i, (v, body) in enumerate(entries):
                if v <= 0: continue
                nxt = entries[i+1][0] if i+1 < len(entries) else maxv + 1
                end = max(v, min(nxt - 1, maxv if maxv else nxt - 1))
                if end < v: end = v
                body = body[:60000]
                c.execute("INSERT INTO commentaries(work,book,chapter,verse_start,verse_end,body) VALUES(?,?,?,?,?,?)",
                          (work, bid, chn, v, end, body))
                n += 1
        con.commit()
        total += n
        print(f"{work}: {n} entries", flush=True)
    c.execute("CREATE INDEX IF NOT EXISTS comm_ref ON commentaries(book,chapter,verse_start)")
    con.commit()
    con.execute("ANALYZE")
    con.commit()
    con.execute("VACUUM")
    con.commit()
    con.close()
    print("DONE", total, f"{time.time()-t0:.1f}s", f"{DB.stat().st_size/1e6:.0f} MB")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Emmaus Bible database importer.
Builds a single read-only SQLite database from public-domain / CC-licensed sources.
"""
import json, os, re, sqlite3, sys, html, csv, io, zipfile, time, unicodedata
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
OUT = ROOT / "Resources"
OUT.mkdir(parents=True, exist_ok=True)
DB_PATH = OUT / "bible.db"

T0 = time.time()
def log(*a):
    print(f"[{time.time()-T0:7.1f}s]", *a, flush=True)

# ---------------------------------------------------------------- books
# order, name, short, osis, testament, genre, aliases
BOOKS = [
    ("Genesis","Gen","Gen","OT","Law",["ge","gn","genesis"]),
    ("Exodus","Exod","Exod","OT","Law",["ex","exo","exod","exodus"]),
    ("Leviticus","Lev","Lev","OT","Law",["le","lv","lev","leviticus"]),
    ("Numbers","Num","Num","OT","Law",["nu","nm","nb","num","numbers"]),
    ("Deuteronomy","Deut","Deut","OT","Law",["dt","de","deu","deut","deuteronomy"]),
    ("Joshua","Josh","Josh","OT","History",["jos","josh","joshua"]),
    ("Judges","Judg","Judg","OT","History",["jdg","jg","judg","judges"]),
    ("Ruth","Ruth","Ruth","OT","History",["ruth","rth","ru"]),
    ("1 Samuel","1 Sam","1Sam","OT","History",["1sa","1sam","1 samuel","i samuel","first samuel"]),
    ("2 Samuel","2 Sam","2Sam","OT","History",["2sa","2sam","2 samuel","ii samuel","second samuel"]),
    ("1 Kings","1 Kgs","1Kgs","OT","History",["1ki","1kg","1kgs","1 kings","i kings","first kings"]),
    ("2 Kings","2 Kgs","2Kgs","OT","History",["2ki","2kg","2kgs","2 kings","ii kings","second kings"]),
    ("1 Chronicles","1 Chr","1Chr","OT","History",["1ch","1chr","1 chronicles","i chronicles","first chronicles"]),
    ("2 Chronicles","2 Chr","2Chr","OT","History",["2ch","2chr","2 chronicles","ii chronicles","second chronicles"]),
    ("Ezra","Ezra","Ezra","OT","History",["ezr","ezra"]),
    ("Nehemiah","Neh","Neh","OT","History",["ne","neh","nehemiah"]),
    ("Esther","Esth","Esth","OT","History",["est","esth","esther"]),
    ("Job","Job","Job","OT","Wisdom",["job","jb"]),
    ("Psalms","Ps","Ps","OT","Wisdom",["ps","psa","pss","psalm","psalms"]),
    ("Proverbs","Prov","Prov","OT","Wisdom",["pr","pro","prov","proverbs"]),
    ("Ecclesiastes","Eccl","Eccl","OT","Wisdom",["ec","ecc","eccl","ecclesiastes"]),
    ("Song of Solomon","Song","Song","OT","Wisdom",["song","sos","sng","canticles","song of songs","song of solomon"]),
    ("Isaiah","Isa","Isa","OT","Major Prophets",["is","isa","isaiah"]),
    ("Jeremiah","Jer","Jer","OT","Major Prophets",["je","jer","jeremiah"]),
    ("Lamentations","Lam","Lam","OT","Major Prophets",["la","lam","lamentations"]),
    ("Ezekiel","Ezek","Ezek","OT","Major Prophets",["eze","ezk","ezek","ezekiel"]),
    ("Daniel","Dan","Dan","OT","Major Prophets",["da","dn","dan","daniel"]),
    ("Hosea","Hos","Hos","OT","Minor Prophets",["ho","hos","hosea"]),
    ("Joel","Joel","Joel","OT","Minor Prophets",["joe","jl","jol","joel"]),
    ("Amos","Amos","Amos","OT","Minor Prophets",["am","amo","amos"]),
    ("Obadiah","Obad","Obad","OT","Minor Prophets",["ob","oba","obad","obadiah"]),
    ("Jonah","Jonah","Jonah","OT","Minor Prophets",["jon","jnh","jonah"]),
    ("Micah","Mic","Mic","OT","Minor Prophets",["mic","micah"]),
    ("Nahum","Nah","Nah","OT","Minor Prophets",["na","nah","nahum"]),
    ("Habakkuk","Hab","Hab","OT","Minor Prophets",["hab","habakkuk"]),
    ("Zephaniah","Zeph","Zeph","OT","Minor Prophets",["zep","zeph","zephaniah"]),
    ("Haggai","Hag","Hag","OT","Minor Prophets",["hag","haggai"]),
    ("Zechariah","Zech","Zech","OT","Minor Prophets",["zec","zech","zechariah"]),
    ("Malachi","Mal","Mal","OT","Minor Prophets",["mal","malachi"]),
    ("Matthew","Matt","Matt","NT","Gospels",["mt","mat","matt","matthew"]),
    ("Mark","Mark","Mark","NT","Gospels",["mk","mr","mrk","mark"]),
    ("Luke","Luke","Luke","NT","Gospels",["lk","luk","luke"]),
    ("John","John","John","NT","Gospels",["jn","jhn","john"]),
    ("Acts","Acts","Acts","NT","History",["ac","act","acts"]),
    ("Romans","Rom","Rom","NT","Pauline Epistles",["ro","rm","rom","romans"]),
    ("1 Corinthians","1 Cor","1Cor","NT","Pauline Epistles",["1co","1cor","1 corinthians","i corinthians"]),
    ("2 Corinthians","2 Cor","2Cor","NT","Pauline Epistles",["2co","2cor","2 corinthians","ii corinthians"]),
    ("Galatians","Gal","Gal","NT","Pauline Epistles",["ga","gal","galatians"]),
    ("Ephesians","Eph","Eph","NT","Pauline Epistles",["ep","eph","ephesians"]),
    ("Philippians","Phil","Phil","NT","Pauline Epistles",["php","phil","philippians"]),
    ("Colossians","Col","Col","NT","Pauline Epistles",["col","colossians"]),
    ("1 Thessalonians","1 Thess","1Thess","NT","Pauline Epistles",["1th","1thess","1 thessalonians","i thessalonians"]),
    ("2 Thessalonians","2 Thess","2Thess","NT","Pauline Epistles",["2th","2thess","2 thessalonians","ii thessalonians"]),
    ("1 Timothy","1 Tim","1Tim","NT","Pauline Epistles",["1ti","1tim","1 timothy","i timothy"]),
    ("2 Timothy","2 Tim","2Tim","NT","Pauline Epistles",["2ti","2tim","2 timothy","ii timothy"]),
    ("Titus","Titus","Titus","NT","Pauline Epistles",["tit","titus"]),
    ("Philemon","Phlm","Phlm","NT","Pauline Epistles",["phm","phlm","philemon"]),
    ("Hebrews","Heb","Heb","NT","General Epistles",["heb","hebrews"]),
    ("James","Jas","Jas","NT","General Epistles",["jas","jam","james"]),
    ("1 Peter","1 Pet","1Pet","NT","General Epistles",["1pe","1pet","1 peter","i peter"]),
    ("2 Peter","2 Pet","2Pet","NT","General Epistles",["2pe","2pet","2 peter","ii peter"]),
    ("1 John","1 John","1John","NT","General Epistles",["1jn","1jo","1john","1 john","i john"]),
    ("2 John","2 John","2John","NT","General Epistles",["2jn","2jo","2john","2 john","ii john"]),
    ("3 John","3 John","3John","NT","General Epistles",["3jn","3jo","3john","3 john","iii john"]),
    ("Jude","Jude","Jude","NT","General Epistles",["jud","jde","jude"]),
    ("Revelation","Rev","Rev","NT","Apocalyptic",["rev","re","apocalypse","revelation of john"]),
]
BOOK_NAMES = {b[0].lower(): i for i, b in enumerate(BOOKS)}
SHORT_NAMES = {b[1].lower(): i for i, b in enumerate(BOOKS)}
ALIAS = {}
for i, b in enumerate(BOOKS):
    for a in b[5]:
        ALIAS[a.lower()] = i
    ALIAS[b[2].lower()] = i
    ALIAS[f"book{i+1}"] = i

# STEPBible / USFM code -> 0-based book index
STEP_CODES = {
 "Gen":0,"Exo":1,"Lev":2,"Num":3,"Deu":4,"Jos":5,"Jdg":6,"Rut":7,"1Sa":8,"2Sa":9,
 "1Ki":10,"2Ki":11,"1Ch":12,"2Ch":13,"Ezr":14,"Neh":15,"Est":16,"Job":17,"Psa":18,
 "Pro":19,"Ecc":20,"Sng":21,"Isa":22,"Jer":23,"Lam":24,"Eze":25,"Dan":26,"Hos":27,
 "Joe":28,"Amo":29,"Oba":30,"Jon":31,"Mic":32,"Nah":33,"Hab":34,"Zep":35,"Hag":36,
 "Zec":37,"Mal":38,"Mat":39,"Mrk":40,"Luk":41,"Jhn":42,"Act":43,"Rom":44,"1Co":45,
 "2Co":46,"Gal":47,"Eph":48,"Php":49,"Col":50,"1Th":51,"2Th":52,"1Ti":53,"2Ti":54,
 "Tit":55,"Phm":56,"Heb":57,"Jas":58,"1Pe":59,"2Pe":60,"1Jn":61,"2Jn":62,"3Jn":63,
 "Jud":64,"Rev":65,
}
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

def norm_book_name(n):
    s = n.strip().lower()
    s = s.replace(".", "").replace("  ", " ")
    if s in ALIAS: return ALIAS[s]
    # Latin vulgate style
    roman = {"i ":1,"ii ":2,"iii ":3}
    for pre, num in roman.items():
        if s.startswith(pre):
            s2 = s[len(pre):]
            key = f"{num} {s2}"
            if key in ALIAS: return ALIAS[key]
    # numeric prefix with space differences
    s2 = re.sub(r"^([1-3])\s*", r"\1 ", s)
    return ALIAS.get(s2)

def norm_strong(s):
    if not s: return None
    s = s.strip().upper().replace("STRONG:", "")
    m = re.match(r"^([HG])0*(\d+)([A-Z]?)$", s)
    if not m: return None
    return f"{m.group(1)}{int(m.group(2))}{m.group(3)}"

def base_strong(s):
    if not s: return None
    m = re.match(r"^([HG]\d+)[A-Z]?$", s)
    return m.group(1) if m else s

TAG_RE = re.compile(r"(<[^>]+>)")
def parse_kjv_osis(verse_text):
    s = verse_text
    s = re.sub(r"<note\b[^>]*>.*?</note>", "", s, flags=re.S)
    s = re.sub(r"<note\b[^>]*/>", "", s)
    s = re.sub(r"<reference\b[^>]*>.*?</reference>", "", s, flags=re.S)
    s = re.sub(r"<milestone\b[^>]*/>", "", s)
    s = re.sub(r"<div\b[^>]*/>", "", s)
    tokens = []
    red = 0; italic = 0; heading = 0; divine = 0
    in_w = False; w_strong = []; w_morph = []; w_buf = None
    out_buf = []
    def emit_text(txt, strongs=None, morph=None):
        nonlocal out_buf
        if not txt: return
        tok = {"t": txt}
        if strongs: tok["s"] = strongs
        if morph: tok["m"] = morph
        if red: tok["r"] = 1
        if italic: tok["i"] = 1
        if heading: tok["h"] = 1
        out_buf.append(tok)
    def flush_text():
        nonlocal out_buf
        if not out_buf: return
        # merge with previous if attributes match
        merged = []
        for tok in out_buf:
            if merged and all(k not in tok for k in ("s","m","r","i","h")) and all(k not in merged[-1] for k in ("s","m","r","i","h")):
                merged[-1]["t"] += tok["t"]
            else:
                merged.append(tok)
        out_buf = merged
    for part in TAG_RE.split(s):
        if not part: continue
        if part.startswith("<"):
            tag = part
            low = tag.lower()
            if low.startswith("</q"):
                red = max(0, red-1)
            elif low.startswith("<q"):
                if 'who="jesus"' in low.replace(" ", ""): red += 1
            elif low.startswith("</transchange"):
                italic = max(0, italic-1)
            elif low.startswith("<transchange"):
                italic += 1
            elif low.startswith("</title"):
                heading = max(0, heading-1)
            elif low.startswith("<title"):
                heading += 1
            elif low.startswith("<divinename"):
                divine += 1
            elif low.startswith("</divinename"):
                divine = max(0, divine-1)
            elif low.startswith("</w"):
                if in_w:
                    txt = "".join(w_buf or [])
                    emit_text(txt, w_strong, w_morph)
                    w_buf = None; in_w = False; w_strong = []; w_morph = []
            elif re.match(r"<w\b", low):
                if low.endswith("/>") or re.search(r"/\s*>$", tag):
                    continue
                in_w = True; w_buf = []; w_strong = []; w_morph = []
                lm = re.search(r'lemma="([^"]*)"', tag)
                if lm:
                    for x in re.findall(r"strong:([HG]\d+[A-Z]?)", lm.group(1)):
                        ns = norm_strong(x)
                        if ns and ns not in w_strong: w_strong.append(ns)
                mm = re.search(r'morph="([^"]*)"', tag)
                if mm:
                    for x in re.split(r"\s+", mm.group(1)):
                        if not x: continue
                        if ":" in x: x = x.split(":",1)[1]
                        x = x.replace("TH", "H")
                        if x and x not in w_morph: w_morph.append(x)
            else:
                # unknown inline tag: ignore
                pass
        else:
            txt = html.unescape(part)
            if divine:
                txt = txt.upper()
            if in_w:
                if w_buf is None: w_buf = []
                w_buf.append(txt)
            else:
                flush_text()
                emit_text(txt)
    if in_w and w_buf:
        emit_text("".join(w_buf), w_strong, w_morph)
    flush_text()
    # merge adjacent plain text runs
    merged = []
    for tok in out_buf:
        if merged and tok.keys() == merged[-1].keys() and "s" not in tok:
            merged[-1]["t"] += tok["t"]
        else:
            merged.append(tok)
    # trim leading/trailing whitespace but keep one
    if merged:
        merged[0]["t"] = merged[0]["t"].lstrip()
        merged[-1]["t"] = merged[-1]["t"].rstrip()
    tokens = [t for t in merged if t["t"]]
    plain = re.sub(r"\s+", " ", "".join(t["t"] for t in tokens)).strip()
    return plain, tokens, any(t.get("r") for t in tokens)

# ---------------------------------------------------------------- db
def create_schema(con):
    c = con.cursor()
    c.executescript("""
    PRAGMA journal_mode=OFF;
    PRAGMA synchronous=OFF;
    PRAGMA temp_store=MEMORY;
    PRAGMA cache_size=-200000;
    CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
    CREATE TABLE translations(
        code TEXT PRIMARY KEY, name TEXT, short TEXT, language TEXT, lang_code TEXT,
        year TEXT, license TEXT, attribution TEXT, has_strongs INT DEFAULT 0,
        has_red INT DEFAULT 0, has_interlinear INT DEFAULT 0,
        source TEXT DEFAULT 'local', bible_id TEXT, sort INT, direction TEXT DEFAULT 'ltr');
    CREATE TABLE books(
        id INTEGER PRIMARY KEY, name TEXT, short TEXT, osis TEXT, testament TEXT,
        genre TEXT, chapters INT, sort INT);
    CREATE TABLE verses(
        translation TEXT, book INT, chapter INT, verse INT, text TEXT, tokens TEXT,
        has_red INT DEFAULT 0,
        PRIMARY KEY(translation, book, chapter, verse)) WITHOUT ROWID;
    CREATE VIRTUAL TABLE search USING fts4(
        translation, book, chapter, verse, text, tokenize=unicode61 "remove_diacritics=1");
    CREATE TABLE strongs(
        id TEXT PRIMARY KEY, lang TEXT, lemma TEXT, translit TEXT, pronounce TEXT,
        derivation TEXT, definition TEXT, kjv_usage TEXT, gloss TEXT, morph TEXT,
        parent TEXT, source TEXT, extended TEXT);
    CREATE TABLE interlinear(
        book INT, chapter INT, verse INT, seq INT, lang TEXT, text TEXT,
        translit TEXT, gloss TEXT, strongs TEXT, morph TEXT,
        PRIMARY KEY(book, chapter, verse, seq)) WITHOUT ROWID;
    CREATE TABLE morph(codes TEXT PRIMARY KEY, lang TEXT, expansion TEXT);
    CREATE TABLE occurrences(
        strongs TEXT, book INT, chapter INT, verse INT, form TEXT, morph TEXT,
        PRIMARY KEY(strongs, book, chapter, verse, form)) WITHOUT ROWID;
    CREATE TABLE cross_refs(
        from_book INT, from_chapter INT, from_verse INT,
        to_book INT, to_chapter INT, to_verse_start INT, to_verse_end INT, votes INT);
    CREATE TABLE dictionary(
        id INTEGER PRIMARY KEY, source TEXT, headword TEXT, body TEXT);
    CREATE TABLE topics(
        id INTEGER PRIMARY KEY, section TEXT, subject TEXT, entry TEXT);
    CREATE TABLE commentaries(
        id INTEGER PRIMARY KEY, work TEXT, book INT, chapter INT, verse_start INT,
        verse_end INT, body TEXT);
    CREATE TABLE plan_days(
        plan TEXT, day INT, reading TEXT, PRIMARY KEY(plan, day));
    """)
    con.commit()

def insert_verse(con, tr, b, ch, v, text, tokens=None, has_red=0, fts=True):
    con.execute("INSERT OR REPLACE INTO verses VALUES(?,?,?,?,?,?,?)",
                (tr, b, ch, v, text, json.dumps(tokens, ensure_ascii=False, separators=(",",":")) if tokens else None, has_red))
    if fts:
        con.execute("INSERT INTO search(translation,book,chapter,verse,text) VALUES(?,?,?,?,?)",
                    (tr, b, ch, v, text))

# ---------------------------------------------------------------- main
def main():
    con = sqlite3.connect(DB_PATH)
    create_schema(con)
    c = con.cursor()

    # books + chapter counts from KJV
    kjv = json.load(open(RAW/"KJV.json"))
    chap_counts = []
    for i, b in enumerate(BOOKS):
        name, short, osis, test, genre, _ = b
        src = kjv["books"][i]
        nch = len(src["chapters"])
        chap_counts.append(nch)
        c.execute("INSERT INTO books VALUES(?,?,?,?,?,?,?,?)", (i+1, name, short, osis, test, genre, nch, i+1))
    con.commit()
    log("books", len(BOOKS), "chapters", sum(chap_counts))

    # translations metadata
    trans = [
      ("NIV","New International Version","NIV","English","en","2011","Copyright Biblica, Inc.","New International Version®, NIV® Copyright © 1973, 1978, 1984, 2011 by Biblica, Inc.® Used by permission. All rights reserved worldwide.",0,0,0,"api","78a9f6124f344018-01",1,"ltr"),
      ("NASB","New American Standard Bible 2020","NASB","English","en","2020","Copyright The Lockman Foundation","New American Standard Bible®, Copyright © 1960, 1971, 1977, 1995, 2020 by The Lockman Foundation. All rights reserved.",0,0,0,"api","a761ca71e0b3ddcf-01",2,"ltr"),
      ("NKJV","New King James Version","NKJV","English","en","1982","Copyright Thomas Nelson","New King James Version®, Copyright © 1982 by Thomas Nelson. Used by permission. All rights reserved.",0,0,0,"api","63097d2a0a2f7db3-01",3,"ltr"),
      ("KJV","King James Version","KJV","English","en","1611 / 1769","Public Domain","King James Version (1769) with Strong's numbers, morphology and red-letter markup.",1,1,0,"local","",10,"ltr"),
      ("BSB","Berean Standard Bible","BSB","English","en","2022","Public Domain / CC0","The Berean Standard Bible is released into the public domain.",0,0,0,"local","",20,"ltr"),
      ("WEB","World English Bible","WEB","English","en","2000","Public Domain","World English Bible (WEB), public domain.",0,1,0,"local","",30,"ltr"),
      ("ASV","American Standard Version","ASV","English","en","1901","Public Domain","American Standard Version (1901), public domain.",0,0,0,"local","",40,"ltr"),
      ("YLT","Young's Literal Translation","YLT","English","en","1898","Public Domain","Young's Literal Translation (1898), public domain.",0,0,0,"local","",50,"ltr"),
      ("HEB","Hebrew Bible — Westminster Leningrad Codex","WLC","Hebrew","he","1008","Public Domain / CC BY","Westminster Leningrad Codex, vowel-pointed. Digital text via Open Scriptures and STEPBible.",1,0,0,"local","",60,"rtl"),
      ("GRK","Greek New Testament","GNT","Greek","grc","2017","CC BY 4.0","Greek New Testament text from STEPBible TAGNT (Tyndale House Cambridge), CC BY 4.0.",1,0,1,"local","",61,"ltr"),
      ("TR","Textus Receptus","TR","Greek","grc","1633","Public Domain","Textus Receptus (Scrivener 1894 family), public domain.",0,0,0,"local","",62,"ltr"),
      ("BYZ","Byzantine Textform","Byz","Greek","grc","2013","Public Domain","The New Testament in the Original Greek: Byzantine Textform 2013.",0,0,0,"local","",63,"ltr"),
      ("VUL","Latin Vulgate — Clementine","VUL","Latin","la","1592","Public Domain","Biblia Sacra Vulgata, Clementine edition, public domain.",0,0,0,"local","",64,"ltr"),
      ("ARB","Arabic Van Dyck Bible","VDV","Arabic","ar","1865","Public Domain","الكتاب المقدس باللغة العربية، فان دايك — Arabic Van Dyck Bible, public domain.",0,0,0,"local","",65,"rtl"),
    ]
    c.executemany("INSERT INTO translations VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", trans)
    con.commit()

    # ---------------- KJV rich text
    log("parsing KJV OSIS")
    osis = json.load(open(RAW/"KJV-osis.json"))
    token_count = 0; occ = []
    for bi, ob in enumerate(osis["books"]):
        src = kjv["books"][bi]
        for ci, ch in enumerate(ob["chapters"]):
            chn = ch["chapter"]
            for v in ch["verses"]:
                vn = v["verse"]
                plain, tokens, red = parse_kjv_osis(v["text"])
                # prefer KJV.json plain text when close enough
                try:
                    ktext = src["chapters"][ci]["verses"][vn-1]["text"]
                    if ktext and abs(len(ktext)-len(plain)) < max(20, len(plain)*0.15):
                        plain = ktext
                except Exception:
                    pass
                insert_verse(con, "KJV", bi+1, chn, vn, plain, tokens, 1 if red else 0)
                token_count += len(tokens)
                for t in tokens:
                    for s in t.get("s", []):
                        occ.append((s, bi+1, chn, vn, t["t"].strip(), ";".join(t.get("m", []))))
    con.commit()
    log("KJV verses done, tokens", token_count, "occurrences", len(occ))
    c.executemany("INSERT OR IGNORE INTO occurrences VALUES(?,?,?,?,?,?)", occ)
    con.commit()
    log("occurrences inserted")

    # ---------------- plain scrollmapper translations
    def load_scroll(code, out_code, name_map=None, skip_apoc=False):
        path = RAW/f"{code}.json"
        if not path.exists():
            log("missing", path); return
        d = json.load(open(path))
        n = 0
        for bi, b in enumerate(d["books"]):
            if name_map is None and bi >= 66: break
            idx = bi
            if name_map: idx = name_map.get(b["name"], -1)
            if idx is None or idx < 0: continue
            if b["name"].lower() in ("tobit","judith","wisdom","sirach","baruch","i maccabees","ii maccabees","prayer of manasses","i esdras","ii esdras","additional psalm","laodiceans"):
                continue
            for ch in b["chapters"]:
                chn = ch.get("chapter", 1)
                for v in ch["verses"]:
                    vn = v["verse"]
                    txt = re.sub(r"\s+", " ", (v.get("text") or "")).strip()
                    if not txt: continue
                    insert_verse(con, out_code, idx+1, chn, vn, txt)
                    n += 1
        con.commit()
        log(out_code, "verses", n)

    for code in ["ASV","BSB","YLT"]:
        load_scroll(code, code)

    # Vulgate mapping
    vulg_map = {}
    for i, b in enumerate(BOOKS):
        vulg_map[b[0]] = i
    vulg_extra = {"I Samuel":8,"II Samuel":9,"I Kings":10,"II Kings":11,"I Chronicles":12,"II Chronicles":13,
                  "Revelation of John":65,"Song of Solomon":21}
    vulg_map.update(vulg_extra)
    load_scroll("VulgClementine","VUL",vulg_map)

    # WLC (39 books)
    wlc = json.load(open(RAW/"WLC.json"))
    n=0
    for bi, b in enumerate(wlc["books"]):
        if bi >= 39: break
        for ch in b["chapters"]:
            for v in ch["verses"]:
                txt=re.sub(r"\s+"," ",(v.get("text") or "")).strip()
                if not txt: continue
                insert_verse(con,"HEB",bi+1,ch.get("chapter",1),v["verse"],txt,fts=False)
                n+=1
    con.commit(); log("HEB verses",n)

    # Arabic Van Dyck
    ar = json.load(open(RAW/"arabic.json"))
    n=0
    for bi,b in enumerate(ar["books"]):
        for chobj in b.get("chapters",[]):
            ch=chobj.get("chapter",{})
            chn=ch.get("number",1)
            for item in ch.get("content",[]):
                if item.get("type")!="verse": continue
                vn=item.get("number")
                parts=[]
                for x in item.get("content",[]):
                    if isinstance(x,str): parts.append(x)
                    elif isinstance(x,dict) and x.get("type")=="text": parts.append(x.get("content",""))
                txt=re.sub(r"\s+"," "," ".join(parts)).strip()
                if not txt: continue
                insert_verse(con,"ARB",bi+1,chn,int(vn),txt,fts=False)
                n+=1
    con.commit(); log("ARB verses",n)

    # ---------------- WEB USFM
    log("parsing WEB USFM")
    usfm_dir = RAW/"web"/"usfm"
    def usfm_tokens(s):
        s = re.sub(r"\\f\b.*?\\f\*", "", s, flags=re.S)
        s = re.sub(r"\\x\b.*?\\x\*", "", s, flags=re.S)
        s = re.sub(r"\\fig\b.*?\\fig\*", "", s, flags=re.S)
        s = s.replace(r"\wj*", "<R>").replace(r"\wj", "<R>")
        # close red at next marker boundary: handled below with \wj* -> </R>
        # redo properly
        s = re.sub(r"\\wj\*", "</R>", s)
        s = re.sub(r"\\wj\b", "<R>", s)
        s = re.sub(r"\\(add|it|qt|em|bdit)\*", "</I>", s)
        s = re.sub(r"\\(add|it|qt|em|bdit)\b", "<I>", s)
        s = re.sub(r"\\nd\*", "</N>", s)
        s = re.sub(r"\\nd\b", "<N>", s)
        def wsub(m):
            txt = m.group(1)
            return txt.split("|")[0]
        s = re.sub(r"\\\+?w\s+([^\\]*?)\\+?w\*", wsub, s)
        s = re.sub(r"\\\+?w\s+([^\\|]*)\|[^\\]*\\\+?w\*", r"\1", s)
        # any remaining markers
        s = re.sub(r"\\[a-zA-Z0-9]+\*?", "", s)
        s = s.replace("~", " ")
        # split on sentinels
        parts = re.split(r"(<R>|</R>|<I>|</I>|<N>|</N>)", s)
        red=0; ital=0; toks=[]
        for p in parts:
            if p=="<R>": red+=1; continue
            if p=="</R>": red=max(0,red-1); continue
            if p=="<I>": ital+=1; continue
            if p=="</I>": ital=max(0,ital-1); continue
            if p=="<N>": continue
            if p=="</N>": continue
            if not p: continue
            txt=html.unescape(p)
            if not txt: continue
            tok={"t":txt}
            if red: tok["r"]=1
            if ital: tok["i"]=1
            toks.append(tok)
        plain=re.sub(r"\s+"," ","".join(t["t"] for t in toks)).strip()
        return plain,toks,any(t.get("r") for t in toks)

    for path in sorted(usfm_dir.glob("*.usfm")):
        m=re.match(r"^\d+-([A-Z0-9]{3})eng-web",path.name)
        if not m: continue
        bi=USFM_CODES.get(m.group(1))
        if bi is None: continue
        chapter=0; verse=None; buf=[]; n=0
        def flush():
            nonlocal verse,buf,n
            if verse is None: return
            plain,toks,red=usfm_tokens(" ".join(buf))
            if plain:
                insert_verse(con,"WEB",bi+1,chapter,verse,plain,toks,1 if red else 0)
                n+=1
            verse=None; buf=[]
        for line in open(path,encoding="utf-8-sig"):
            line=line.rstrip("\n")
            cm=re.match(r"^\\c\s+(\d+)",line)
            if cm:
                flush(); chapter=int(cm.group(1)); continue
            vm=re.match(r"^\\v\s+(\d+)(?:-(\d+))?\s*(.*)$",line)
            if vm:
                flush(); verse=int(vm.group(1)); buf=[vm.group(3)]; continue
            if line.startswith("\\"):
                if line.startswith(("\\s","\\r","\\d","\\p","\\q","\\m","\\b","\\li","\\pi","\\nb","\\cls","\\qa","\\qc","\\qm","\\qr","\\qs","\\ts","\\toc","\\mt","\\h","\\ide","\\rem","\\sts")):
                    continue
                if verse is not None:
                    buf.append(line)
                continue
            if verse is not None:
                buf.append(line)
        flush()
        con.commit()
        log("WEB", path.name, n)

    # ---------------- Greek NT from TAGNT / interlinear
    log("parsing STEPBible interlinear")
    step_files = sorted((RAW/"stepbible").glob("TAHOT-*.txt")) + sorted((RAW/"stepbible").glob("TAGNT-*.txt"))
    inter_rows=[]
    gnt=defaultdict(list)  # (book,ch,v) -> words in order
    verse_seq=defaultdict(int)
    for path in step_files:
        lang = "he" if "TAHOT" in path.name else "grc"
        for line in open(path,encoding="utf-8-sig"):
            line=line.rstrip("\n")
            m=re.match(r"^([A-Za-z0-9]+)\.(\d+)\.(\d+)#(\d+)(?:=[^\t]*)?\t(.*)$",line)
            if not m: continue
            code,chn,vn,seq,rest=m.group(1),int(m.group(2)),int(m.group(3)),int(m.group(4)),m.group(5)
            bi=STEP_CODES.get(code)
            if bi is None: continue
            if vn==0: continue
            cols=rest.split("\t")
            if lang=="he":
                if len(cols)<6: continue
                heb=cols[0].replace("/","").replace("\\","").strip()
                translit=cols[1].strip()
                gloss=cols[2].strip()
                dstrong=cols[3]
                morph=cols[4].strip()
                sm=re.findall(r"\{([HG]\d{1,5})[A-Z]?\}",dstrong)
                if not sm:
                    sm=re.findall(r"([HG]\d{1,5})",dstrong)
                strongs=norm_strong(sm[0]) if sm else None
                text=heb
            else:
                if len(cols)<4: continue
                greek=cols[0].strip()
                tm=re.search(r"\(([^)]*)\)",greek)
                translit=tm.group(1) if tm else ""
                text=re.sub(r"\s*\([^)]*\)","",greek).strip()
                gloss=cols[1].strip()
                dg=cols[2]
                morph=(dg.split("=",1)[1] if "=" in dg else "").strip()
                sm=re.findall(r"([HG]\d{1,5})",dg.split("=",1)[0])
                strongs=norm_strong(sm[0]) if sm else None
            if not text: continue
            k=(bi+1,chn,vn)
            seq2=verse_seq[k]; verse_seq[k]+=1
            inter_rows.append((bi+1,chn,vn,seq2,lang,text,translit,gloss,strongs or "",morph))
            if lang=="grc":
                gnt[k].append(text)
    c.executemany("INSERT OR REPLACE INTO interlinear VALUES(?,?,?,?,?,?,?,?,?,?)",inter_rows)
    con.commit()
    log("interlinear rows",len(inter_rows))
    # Greek NT reading text reconstructed from TAGNT
    n=0
    for (bi,chn,vn),words in gnt.items():
        txt=" ".join(words)
        txt=re.sub(r"\s+"," ",txt).strip()
        if txt:
            insert_verse(con,"GRK",bi,chn,vn,txt,fts=False)
            n+=1
    con.commit(); log("GRK verses",n)

    # TR / BYZ plain (accentless, useful for apparatus)
    load_scroll("TR","TR")
    load_scroll("Byz","BYZ")

    # ---------------- Strong's lexicons
    log("loading Strong's lexicons")
    def load_js_dict(path):
        s=open(path,encoding="utf-8-sig").read()
        i=s.find("{")
        j=s.rfind("}")
        return json.loads(s[i:j+1])
    heb=load_js_dict(RAW/"strongs-hebrew.js")
    grk=load_js_dict(RAW/"strongs-greek.js")
    rows=[]
    for k,v in heb.items():
        sid=norm_strong(k)
        if not sid: continue
        rows.append((sid,"he",v.get("lemma",""),v.get("xlit",""),v.get("pron",""),v.get("derivation",""),v.get("strongs_def",""),v.get("kjv_def",""),"","","openScriptures",""))
    for k,v in grk.items():
        sid=norm_strong(k)
        if not sid: continue
        rows.append((sid,"grc",v.get("lemma",""),v.get("xlit",""),v.get("pron",""),v.get("derivation",""),v.get("strongs_def",""),v.get("kjv_def",""),"","","openScriptures",""))
    c.executemany("INSERT OR REPLACE INTO strongs(id,lang,lemma,translit,pronounce,derivation,definition,kjv_usage,gloss,morph,source,extended) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",rows)
    con.commit(); log("Strong's base entries",len(rows))

    def strip_html(s):
        if not s: return ""
        s=s.replace("<BR />","\n").replace("<BR/>","\n").replace("<br />","\n").replace("<br/>","\n")
        s=re.sub(r"<ref='([^']*)'>",r"",s)
        s=re.sub(r"</ref>","",s)
        s=re.sub(r"<[^>]+>","",s)
        s=html.unescape(s)
        return re.sub(r"[ \t]+"," ",s).strip()

    def load_brief(path, lang):
        out=[]; n=0
        for line in open(path,encoding="utf-8-sig"):
            cols=line.rstrip("\n").split("\t")
            if len(cols)<7: continue
            e, d, u, lemma, translit, morph, gloss = cols[0],cols[1],cols[2],cols[3],cols[4],cols[5],cols[6]
            if not re.match(r"^[HG]\d",e): continue
            definition=strip_html(cols[7] if len(cols)>7 else "")
            sid=norm_strong(d.split("=")[0].strip()) or norm_strong(e)
            if not sid: continue
            parent=norm_strong(e)
            out.append((sid,lang,lemma,translit,"","",definition,"",gloss,morph,parent,"STEPBible",definition))
            n+=1
        return out
    brief = load_brief(RAW/"stepbible"/"TBESH.txt","he") + load_brief(RAW/"stepbible"/"TBESG.txt","grc")
    # update existing base entries with brief info, insert extended entries
    for r in brief:
        sid,lang,lemma,translit,_,_,definition,_,gloss,morph,parent,source,extended=r
        cur=c.execute("SELECT id FROM strongs WHERE id=?",(sid,)).fetchone()
        if cur:
            c.execute("""UPDATE strongs SET lemma=COALESCE(NULLIF(?,''),lemma),
                         translit=COALESCE(NULLIF(?,''),translit), gloss=COALESCE(NULLIF(?,''),gloss),
                         morph=COALESCE(NULLIF(?,''),morph), extended=? WHERE id=?""",
                      (lemma,translit,gloss,morph,extended,sid))
        else:
            c.execute("INSERT INTO strongs(id,lang,lemma,translit,pronounce,derivation,definition,kjv_usage,gloss,morph,parent,source,extended) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
                      (sid,lang,lemma,translit,"","",definition,"",gloss,morph,parent,"STEPBible",extended))
    con.commit(); log("brief lexicon entries",len(brief))

    # ---------------- morphology
    log("loading morphology")
    mcodes=[]
    for path,lang in [(RAW/"stepbible"/"TEHMC.txt","he"),(RAW/"stepbible"/"TEGMC.txt","grc")]:
        for line in open(path,encoding="utf-8-sig"):
            cols=line.rstrip("\n").split("\t")
            if len(cols)>=2 and "Function=" in cols[1]:
                code=cols[0].strip(); exp=strip_html(cols[1])
                if code and len(code)<40:
                    mcodes.append((code,lang,exp))
    c.executemany("INSERT OR REPLACE INTO morph VALUES(?,?,?)",mcodes)
    con.commit(); log("morph codes",len(mcodes))

    # ---------------- cross references
    log("loading cross references")
    def parse_ref(x):
        x=x.strip()
        m=re.match(r"^([1-3]?[A-Za-z]+)\.(\d+)\.(\d+)(?:-([1-3]?[A-Za-z]+)\.(\d+)\.(\d+))?$",x)
        if not m: return None
        b=ALIAS.get(m.group(1).lower())
        if b is None: return None
        c1=int(m.group(2)); v1=int(m.group(3))
        if m.group(4):
            b2=ALIAS.get(m.group(4).lower())
            if b2 is None: return None
            return b,c1,v1,b2,int(m.group(5)),int(m.group(6))
        return b,c1,v1,b,c1,v1
    xrows=[]
    with open(RAW/"cross_references.txt",encoding="utf-8",errors="ignore") as f:
        for line in f:
            if line.startswith("From Verse"): continue
            parts=line.rstrip("\n").split("\t")
            if len(parts)<3: continue
            a=parse_ref(parts[0]); b=parse_ref(parts[1])
            if not a or not b: continue
            try: votes=int(parts[2])
            except: votes=0
            xrows.append((a[0]+1,a[1],a[2],b[0]+1,b[1],b[3],b[5],votes))
    c.executemany("INSERT INTO cross_refs VALUES(?,?,?,?,?,?,?,?)",xrows)
    con.execute("CREATE INDEX cr_from ON cross_refs(from_book,from_chapter,from_verse)")
    con.execute("CREATE INDEX cr_to ON cross_refs(to_book,to_chapter,to_verse_start)")
    con.commit(); log("cross refs",len(xrows))

    # ---------------- dictionaries
    log("loading dictionaries")
    drows=[]
    srcmap={"EAS":"Easton","SMI":"Smith","HTT":"Hitchcock"}
    for p in sorted((RAW/"dict").glob("*.json")):
        try: d=json.load(open(p,encoding="utf-8-sig"))
        except Exception as e: log("dict error",p,e); continue
        if isinstance(d,dict):
            for head,entry in d.items():
                if not isinstance(entry,dict): continue
                for df in entry.get("definitions",[]):
                    body=strip_html(df.get("text",""))
                    if body:
                        drows.append((srcmap.get(df.get("source"),df.get("source","Dictionary")),head,body))
    # Hitchcock
    with open(RAW/"Hitchcock.json",encoding="utf-8-sig") as f:
        for row in csv.reader(f):
            if len(row)>=2 and row[0].lower()!="name":
                drows.append(("Hitchcock",row[0],row[1]))
    c.executemany("INSERT INTO dictionary(source,headword,body) VALUES(?,?,?)",drows)
    con.execute("CREATE INDEX dict_head ON dictionary(headword COLLATE NOCASE)")
    con.execute("CREATE INDEX dict_src ON dictionary(source)")
    con.commit(); log("dictionary entries",len(drows))

    # ---------------- Nave's topics
    log("loading Nave's topics")
    trows=[]
    with open(RAW/"Naves.json",encoding="utf-8-sig") as f:
        r=csv.reader(f)
        header=next(r,None)
        for row in r:
            if len(row)>=3 and row[1].strip():
                trows.append((row[0].strip(),row[1].strip(),row[2].strip()))
    c.executemany("INSERT INTO topics(section,subject,entry) VALUES(?,?,?)",trows)
    con.execute("CREATE INDEX topics_subject ON topics(subject COLLATE NOCASE)")
    con.commit(); log("topics",len(trows))

    # ---------------- meta
    c.executemany("INSERT OR REPLACE INTO meta VALUES(?,?)",[
        ("schema","1"),("built",time.strftime("%Y-%m-%d")),
        ("sources","KJV OSIS (Open Scriptures), scrollmapper, STEPBible (CC BY 4.0), openbible.info (CC BY), Open Scriptures Strong's (CC BY-SA), neuu-org dictionaries, Nave's/Hitchcock (public domain)"),
    ])
    con.commit()
    log("analyzing")
    con.execute("ANALYZE")
    con.commit()
    con.execute("VACUUM")
    con.commit()
    con.close()
    log("DONE", DB_PATH, f"{DB_PATH.stat().st_size/1e6:.0f} MB")

if __name__ == "__main__":
    main()

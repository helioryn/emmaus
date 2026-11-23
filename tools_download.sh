#!/bin/bash
set -u
cd "$(dirname "$0")"
mkdir -p data/raw/stepbible data/raw/web data/raw/dict
BASE="https://raw.githubusercontent.com/STEPBible/STEPBible-Data/master"
dl() { curl -sSL --retry 3 --retry-delay 2 -m 900 -o "$2" "$1" && echo "OK $2 $(du -h "$2" | cut -f1)" || echo "FAIL $1"; }

dl "$BASE/Translators%20Amalgamated%20OT%2BNT/TAHOT%20Gen-Deu%20-%20Translators%20Amalgamated%20Hebrew%20OT%20-%20STEPBible.org%20CC%20BY.txt" data/raw/stepbible/TAHOT-Gen-Deu.txt &
dl "$BASE/Translators%20Amalgamated%20OT%2BNT/TAHOT%20Job-Sng%20-%20Translators%20Amalgamated%20Hebrew%20OT%20-%20STEPBible.org%20CC%20BY.txt" data/raw/stepbible/TAHOT-Job-Sng.txt &
dl "$BASE/Translators%20Amalgamated%20OT%2BNT/TAHOT%20Isa-Mal%20-%20Translators%20Amalgamated%20Hebrew%20OT%20-%20STEPBible.org%20CC%20BY.txt" data/raw/stepbible/TAHOT-Isa-Mal.txt &
dl "$BASE/Translators%20Amalgamated%20OT%2BNT/TAHOT%20Jos-Est%20-%20Translators%20Amalgamated%20Hebrew%20OT%20-%20STEPBible.org%20CC%20BY.txt" data/raw/stepbible/TAHOT-Jos-Est.txt &
dl "$BASE/Translators%20Amalgamated%20OT%2BNT/TAGNT%20Mat-Jhn%20-%20Translators%20Amalgamated%20Greek%20NT%20-%20STEPBible.org%20CC-BY.txt" data/raw/stepbible/TAGNT-Mat-Jhn.txt &
dl "$BASE/Translators%20Amalgamated%20OT%2BNT/TAGNT%20Act-Rev%20-%20Translators%20Amalgamated%20Greek%20NT%20-%20STEPBible.org%20CC-BY.txt" data/raw/stepbible/TAGNT-Act-Rev.txt &
dl "$BASE/Lexicons/TBESH%20-%20Translators%20Brief%20lexicon%20of%20Extended%20Strongs%20for%20Hebrew%20-%20STEPBible.org%20CC%20BY.txt" data/raw/stepbible/TBESH.txt &
dl "$BASE/Lexicons/TBESG%20-%20Translators%20Brief%20lexicon%20of%20Extended%20Strongs%20for%20Greek%20-%20STEPBible.org%20CC%20BY.txt" data/raw/stepbible/TBESG.txt &
dl "$BASE/Morphology%20codes/TEGMC%20-%20Translators%20Expansion%20of%20Greek%20Morphhology%20Codes%20-%20STEPBible.org%20CC%20BY.txt" data/raw/stepbible/TEGMC.txt &
dl "$BASE/Morphology%20codes/TEHMC%20-%20Translators%20Expansion%20of%20Hebrew%20Morphology%20Codes%20-%20STEPBible.org%20CC%20BY.txt" data/raw/stepbible/TEHMC.txt &
dl "https://raw.githubusercontent.com/openscriptures/strongs/master/hebrew/strongs-hebrew-dictionary.js" data/raw/strongs-hebrew.js &
dl "https://raw.githubusercontent.com/openscriptures/strongs/master/greek/strongs-greek-dictionary.js" data/raw/strongs-greek.js &
dl "https://ebible.org/Scriptures/eng-web_usfm.zip" data/raw/web/eng-web_usfm.zip &
dl "https://raw.githubusercontent.com/garydavenport73/eastons-bible-dictionary-json/main/eastons.json" data/raw/eastons.json &

# neuu merged dictionary letters (Easton + Smith + Hitchcock)
for L in a b c d e f g h i j k l m n o p q r s t u v w y z; do
  dl "https://raw.githubusercontent.com/neuu-org/bible-dictionary-dataset/main/data/01_parsed/$L.json" "data/raw/dict/$L.json" &
done

wait
echo "ALL DOWNLOADS FINISHED"

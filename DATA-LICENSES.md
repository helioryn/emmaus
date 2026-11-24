# Data licenses and attribution

Emmaus bundles a lot of material written by other people. This file records where
every piece came from, under what terms, and what a distributor must display.

**The application code is GPL-3.0 ([LICENSE](LICENSE)).** The data below is *not*
covered by that license; each source keeps its own terms. If you distribute a
build of Emmaus, or a fork, you must preserve the attributions listed here.

## Scripture translations

### Bundled — public domain

| Code | Translation | Source |
|---|---|---|
| KJV | King James Version (1769), with Strong's numbers, morphology, red letters | Open Scriptures Hebrew Bible / KJV OSIS project |
| BSB | Berean Standard Bible | berean.bible; dedicated to the public domain (CC0) |
| WEB | World English Bible | eBible.org / Michael Johnson |
| ASV | American Standard Version (1901) | eBible.org / public domain |
| YLT | Young's Literal Translation (1898) | eBible.org / public domain |
| TR | Textus Receptus (Scrivener 1894 family) | public domain |
| BYZ | Byzantine Textform 2013 | Robinson–Pierpont; public domain |
| VUL | Clementine Vulgate (1598) | public domain |
| ARB | Arabic Van Dyck | public domain |
| BBE | Bible in Basic English (1949) | eBible.org (`engBBE`) |
| DBY | Darby Translation (1890) | eBible.org (`engDBY`) |
| DRA | Douay-Rheims (1899) | eBible.org (`engDRA`) |
| GNV | Geneva Bible (1599) | eBible.org (`enggnv`) |
| MSB | Majority Standard Bible | eBible.org (`engmsb`) |
| RV | Revised Version (1885) | eBible.org (`eng-rv`) |
| WBT | Webster Bible (1833) | eBible.org (`engwebster`) |
| WMB | World Messianic Bible | eBible.org (`engwmb`) |
| CUVS / CUVT | Chinese Union Version, simplified / traditional (1919) | eBible.org (`cmn-cu89s`, `cmn-cu89t`) |
| RVR | Reina Valera (1909) | eBible.org (`spaRV1909`) |
| LSG | Louis Segond (1910) | eBible.org (`fraLSG`) |
| LUT | Luther Bible (1912) | eBible.org (`deu1912`) |
| VFL | World Portuguese Bible | eBible.org (`porbrbsl`) |
| RIV | Riveduta (1927) | eBible.org (`ita1927`) |
| SYN | Russian Synodal Bible (1876) | eBible.org (`russyn`) |
| HSV | Dutch Bible (1917) | eBible.org (`nld`) |
| KOR | Korean Bible (1910) | eBible.org (`kor`) |
| JPB | Japanese Freedom Bible | eBible.org (`jpnm`) |
| VIE | Vietnamese Bible (1923) | eBible.org (`vie1934`) |
| THA | Thai Freedom Bible | eBible.org (`thafb`) |
| UKR | Ukrainian Bible (Kulish, 1871) | eBible.org (`ukr1871`) |
| RON | Romanian Bible (1924) | eBible.org (`ron1924`) |
| CEP | Czech Kralická Bible (1613) | eBible.org (`ces1613`) |
| SRP | Serbian Bible (1868) | eBible.org (`srp1868`) |
| MYA | Burmese Common Language Bible | eBible.org (`mya`) |
| EPO | Esperanto Bible | eBible.org (`epo`) |
| HAW | Hawaiian Bible (1868) | eBible.org (`haw1868`) |
| HAT | Haitian Creole Bible (1985) | eBible.org (`hat`) |
| PES | Old Persian Version (1895) | eBible.org (`pesOPV`) |

eBible.org distributes these texts with a per-translation license statement in
`translations.csv`; each one above is marked there as public domain. The importer
at `tools/import_free_bibles.py` reads from `https://ebible.org/Scriptures/`.

### Bundled — openly licensed

| Code | Translation | License | Obligation |
|---|---|---|---|
| HEB | Westminster Leningrad Codex (vowel-pointed) | Public domain text; digitisation by Open Scriptures / STEPBible under **CC BY 4.0** | Attribute Open Scriptures and STEPBible |
| GRK | Greek New Testament (TAGNT) | **CC BY 4.0**, Tyndale House Cambridge | Attribute "STEPBible.org, CC BY 4.0" |

### Not bundled — licensed translations

NIV, NASB, and NKJV are **never** bundled or redistributed. They are fetched
chapter by chapter from [API.Bible](https://api.bible) using a key that the *user*
supplies, under that user's own agreement with API.Bible. Cached chapters are
refreshed every 30 days and the copyright notice returned by the API is displayed
in the reader.

| Translation | Rights holder |
|---|---|
| NIV | Biblica, Inc.® |
| NASB | The Lockman Foundation |
| NKJV | Thomas Nelson |

Adding a key does not grant redistribution rights, and neither does this project.
Do not add code that stores or ships one shared key.

## Study material

| Material | License | Obligation |
|---|---|---|
| Cross-references (344,000, vote-ranked) | **CC BY**, openbible.info | Attribute openbible.info |
| STEPBible lexicons TBESH / TBESG | **CC BY 4.0**, Tyndale House Cambridge | Attribute STEPBible.org |
| STEPBible morphology codes (TEGMC / TEHMC) | **CC BY 4.0** | Attribute STEPBible.org |
| Open Scriptures Strong's Hebrew and Greek dictionaries | **CC BY-SA** | Attribute, share-alike on the data |
| Tyndale Open Study Notes | **CC BY-SA** | Attribute, share-alike on the data |
| Matthew Henry Commentary | Public domain | None |
| Jamieson–Fausset–Brown | Public domain | None |
| Geneva Bible notes (1599) | Public domain | None |
| Scofield Reference Notes (1917) | Public domain | None |
| Easton's, Smith's, Hitchcock's dictionaries | Public domain | None |
| Nave's Topical Bible | Public domain | None |

Where a source is CC BY-SA, the *data* remains under CC BY-SA even though the
application code is GPL-3.0. Redistributing a modified database of those notes
requires releasing that database under the same terms.

## What the app displays

Emmaus shows the attribution for openly licensed data in the reader footer and in
Settings → About, and the API.Bible copyright line under every fetched chapter.
A fork must keep those notices intact.

## If you are adding data

See [CONTRIBUTING.md](CONTRIBUTING.md#adding-a-bible). A pull request that adds a
translation or dataset without updating this file will not be merged.

## Reporting a licensing problem

If you believe something here is attributed incorrectly or should not be bundled,
open an issue or email **licensing@helioryn.com**. It will be removed first and
discussed afterwards.

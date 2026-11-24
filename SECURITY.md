# Security policy

## Reporting a vulnerability

**Please do not open a public issue.**

Report privately through GitHub's [private vulnerability reporting](../../security/advisories/new),
or by email to **security@helioryn.com**.

Include:

- What the issue is and where (file, screen, or endpoint)
- Steps to reproduce, or a proof of concept
- The version, platform, and build (macOS or Android)
- Whether it can expose a user's notes, reading history, or API key

You will get an acknowledgement within **3 business days** and an assessment within
**10 business days**. If the report is valid, a fix and a coordinated disclosure
date will be agreed with you, and you will be credited unless you prefer not to be.

## Scope

In scope:

- The macOS and Android applications in this repository
- Data handling: notes, highlights, bookmarks, reading history
- API key storage and transmission
- The import and database-generation scripts in `tools/` (for example, path
  traversal or unexpected code execution from a malicious source file)
- Anything that could silently send user data off-device

Out of scope:

- Vulnerabilities in third-party dependencies that are already public and have no
  exploit path in this app (report those upstream, but tell us)
- Issues requiring physical access to an unlocked, already-compromised device
- Denial of service by feeding the app a corrupted database you built yourself
- The lack of code signing on development builds

## How this app handles sensitive data

- **Bible text, notes, highlights, and history** are stored locally in
  `~/Library/Application Support/Emmaus/user.db` on macOS and in app-private
  storage on Android. Nothing is uploaded.
- **The API.Bible key**, if you add one, is stored locally — in `config.json` with
  mode `0600` on macOS, in app-private storage on Android. It is sent only to
  `rest.api.bible` over HTTPS and never logged or included in exports.
- **Export** (JSON and Markdown) is initiated by the user and written wherever they
  choose. It does not include the API key. Android cloud backup is disabled, so
  notes and keys are not copied to a Google account.
- There is **no telemetry, crash uploader, or analytics SDK** in the project. A pull
  request that adds one will be rejected.

## Supported versions

The `main` branch and the latest release are supported. There are no long-term
support branches; fixes ship forward.

## Safe harbour

We will not pursue legal action against researchers who follow this policy, test
only against their own installation, avoid privacy violations and data
destruction, and give us reasonable time to fix the issue before disclosure.

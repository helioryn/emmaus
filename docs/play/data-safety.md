# Data safety answers

Play's Data safety form, answered for the current build. Re-check this whenever
a dependency or feature changes; an inaccurate declaration is a policy issue.

## Collection and sharing

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all user data encrypted in transit? | **Yes** (HTTPS only; cleartext is disabled) |
| Do you provide a way for users to request data deletion? | **Yes** — uninstall removes all local data; export before uninstalling |

## Why "no collection" is accurate

- No account, sign-in, analytics, crash reporting, advertising or attribution SDK.
- Notes, highlights, bookmarks, history, plan progress and preferences never
  leave the device.
- The optional API.Bible key is entered by the user, stored encrypted with the
  Android Keystore, and sent only to `rest.api.bible` when the user opens a
  licensed translation. It is not collected by the developer and there is no
  developer server.
- No data is sold or shared with third parties.

## Permissions

| Permission | Why |
|---|---|
| `INTERNET` | Only for the optional API.Bible translations the user configures |

No location, contacts, storage, camera, microphone or notification permission is
requested.

## Content

- App contains no ads and no in-app purchases.
- Religious content: answer the content-rating questionnaire as "reference /
  educational" with scripture quotations. No violence, gambling, or user-generated
  content is published; notes are private to the device.

## Ads and purchases

- Contains ads: **No**
- In-app purchases: **No**

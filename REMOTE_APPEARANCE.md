# Remote appearance

The SDK reads `data.appearance` from `GET /consent/config?code_config=...` with
its existing integration header. Normal form loading shares the content response;
there is no additional appearance request. Validated schema 1 tokens are persisted
per base URL, API path and integration key without TTL or background checks.
Consent content still loads normally, but subsequent responses do not replace a
cached appearance. Missing/invalid appearance uses defaults without failing consent
loading. Standalone `getAppearance()` on a cache miss and explicit
`refreshAppearance()` fetch `/consent/config` to read `data.appearance`.
The native form model applies appearance to SwiftUI and the UIKit hosting controller.
An explicitly supplied `ConsentTheme` takes precedence over remote colors/shapes.

```swift
let appearance = await cmp.getAppearance()
let refreshed = await cmp.refreshAppearance() // failure preserves the previous profile
await cmp.clearAppearanceCache()             // does not remove consent or visitor ID
```

Open forms keep their snapshot until loaded again. Offline first loads use SDK
defaults and retry in the next SDK session. Font assets use public HTTPS URLs and
SHA-256, accept at most four files of 4 MB each, and persist beside the profile.
Missing/broken fonts fall back to system fonts without network retries. Explicit
refresh can retry font assets. App-registered fonts use their PostScript name.
Content-addressed font files may be shared by profiles and remain after clearing
one profile; clearing app data removes all. App backup/restore policy controls
whether an installation restores old profiles.

Backend contract and portal are described in Android's REMOTE_APPEARANCE.md.
Windows validation checks syntax only; run `swift test` and the example on a Mac
before publishing iOS support.

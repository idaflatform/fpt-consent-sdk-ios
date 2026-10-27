# Remote appearance

The SDK reads `/appearance` once for each base URL, API path and integration key,
persists validated schema 1 tokens in Application Support, and reuses them without
TTL or background version checks. Consent content still loads using `/config`.
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

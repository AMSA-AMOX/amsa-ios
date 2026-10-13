# AMSA iOS

Native SwiftUI port of the AMSA web dashboard ([www.amsa.mn](https://www.amsa.mn)). It replicates the website's mobile UI screen by screen and talks to the same live API (`https://www.amsa.mn/api/*`). iOS 17+, iPhone only, portrait only, no third-party packages.

## Requirements

- Xcode 26: `sudo xcode-select -s /Applications/Xcode.app` after installing.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.
- Node 20+, only to regenerate resources under `tools/`.

## Setup

```sh
scripts/gen-secrets.sh        # .env → Config/Secrets.xcconfig (public keys only, gitignored)
xcodegen                      # project.yml → AMSA.xcodeproj (generated, gitignored)
open AMSA.xcodeproj
```

- `scripts/gen-secrets.sh` copies only `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_LOGO_DEV_TOKEN` and `NEXT_PUBLIC_TURNSTILE_SITE_KEY`. Server secrets (`JWT_SECRET`, `TURNSTILE_SECRET_KEY`, `RESEND_*`, `PEXELS_API_KEY`, `COLLEGE_SCORECARD_API_KEY`) must never reach the app, because anything in an IPA can be extracted.
- `AMSA_DEVELOPMENT_TEAM` in `Config/Base.xcconfig` is the paid Apple Developer Program team (`4W55D23N4Z`), which signs device and TestFlight builds.
- Push notifications are on (`AMSA_CODE_SIGN_ENTITLEMENTS = AMSA/AMSA.entitlements`). To build with a free Personal Team instead, change the team and empty that setting, because free teams can't sign push. The website side is in the website repo's `src/lib/push.ts`; it needs the `APNS_KEY`, `APNS_KEY_ID` and `APNS_TEAM_ID` environment variables. Local notifications (the welcome after signup) work either way.
- Re-run `xcodegen` after adding or removing files.

## Tests

| Command | Needs | Covers |
|---|---|---|
| `xcodebuild test -scheme AMSA -destination 'platform=iOS Simulator,name=iPhone 17'` | Xcode | Everything: unit tests, the live contract test (opt-in), UI smoke tests |
| `scripts/test-core.sh` | Command Line Tools | Unit tests for the Foundation-only logic, run on macOS |
| `scripts/typecheck.sh` | Command Line Tools | Swift 6 strict-concurrency typecheck of the whole app (as Mac Catalyst) |

- **Live contract test.** Set `AMSA_TEST_EMAIL` and `AMSA_TEST_PASSWORD` in the scheme's Test environment (project.yml). It logs in, then decodes every GET endpoint against production to catch schema drift. There is no staging backend.
- **Where expectations come from.** Values for JS semantics (dates, time zones, `Math.round`, social handles, logo lookup, topic regex) were computed by running the website's own code in Node.

## Regenerating resources

The resources below are generated, not hand-written. The generators read the read-only `reference-amsa-website/` checkout.

```sh
cd tools && npm ci
npm run palette   # Tailwind 4.2.0 OKLCH → Display P3   → AMSA/DesignSystem/Palette.swift
npm run map       # d3-geo geoAlbersUsa, fitSize 975×610 → AMSA/Resources/Data/us-states.json
npm run data      # states, constants, logo aliases      → AMSA/Resources/Data/*.json
npm run icons     # inline <svg>s listed in icons.json   → Assets.xcassets/Icons (template vectors)
```

## Layout

```
AMSA/App/            entry point, root auth gate, shared services
AMSA/Core/           API client and endpoints, models, session, storage, JS-semantics utilities
AMSA/DesignSystem/   palette, Tailwind type scale, effects, web-equivalent components
AMSA/Shell/          tab root, top pill bar, screen headers, routes, shell badges, feedback
AMSA/Features/       one folder per dashboard area; each file starts with `// Port of <web path>`
AMSA/Resources/      fonts (Urbanist, OFL), data JSON, asset catalog, PrivacyInfo.xcprivacy
AMSATests/           Swift Testing unit + contract tests
AMSAUITests/         XCUITest smoke tests
tools/  scripts/  Config/
```

## Porting rules

- **The web source is the spec.** Copy, metrics, role gates and client logic come from the web file named in each `// Port of` header.
- **Units.** 1 CSS px = 1 pt; Tailwind spacing `n` = 4n pt.
- **Button corners.** The global `.dashboard button { border-radius: 4px }` gives every dashboard `<button>` 4 pt corners (`TW.dashboardButtonRadius`). Links, labels and inputs keep their class radius.
- **Fonts.** The web loads Urbanist 400/500/600 only, so bold and black render with the SemiBold face.
- **Disabled form controls.** Tailwind's preflight sets `opacity: 1`, so disabled inputs look normal unless the web adds `disabled:opacity-*` (`InputStyle.disabledOpacity`).
- **Deliberate deviations.** These are the only ones:
  - Navigation is the app's own, replacing the web's sidebar, top bar and page titles. A top pill bar holds Profile, Home, Network, Colleges, Places and Notifications. Home combines Feed and Threads. Each tab has its own floating bottom bar for filters, search, compose and the Compare sheet. Profile, Notifications and every detail page open as pushed screens with a back button. Settings (the gear on Profile) holds sign-out, feedback, legal links, the membership application and the admin queues. Filter panels are bottom sheets.
  - Places carousel is rebuilt to work on phones.
  - Colleges has no US state map (or its state filter). College detail has no Google Maps embed and no data-source note, and it hides the AMSA members and posts sections when they're empty.
  - Colleges has no US state map (or its state filter). College detail has no Google Maps embed and no data-source note.
  - Hover-only controls are visible or tap-driven.
  - Native alerts and Safari view replace their browser equivalents.
  - Any 401 signs the user out.
  - Password reset happens on the website.
  - Small bug fixes, with copy and layout unchanged: College detail shows its "College not found." fallback, the "Your question has been sent!" message is visible, and the Inbox treats ambassadors as recipients (matching the server).
- **Web-only screens.** These are intentionally not in the app: Admin › Members (role management, IPEDS import, rank and college sync), Events and Guide. Event notifications still appear in Notifications but aren't tappable.

## Release (TestFlight)

1. Set the version in `Config/Base.xcconfig` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`).
2. `xcodegen`, then in Xcode choose Product › Archive and Distribute App › App Store Connect.

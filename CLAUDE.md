# Hypeshot

Free macOS screenshot app with a one-time "Unlock Pro" StoreKit 2 in-app purchase ($7.99). Mac App Store portfolio project.
Approved decisions (2026-07-03): name **Hypeshot**, bundle ID `com.shafi.hypeshot`, Pro price **$7.99** one-time, product ID `com.shafi.hypeshot.pro`.

## Product decisions
- Distribution: Mac App Store, sandboxed. Target: macOS 26 (Tahoe), Xcode 26.6, Swift/SwiftUI.
- Monetization: single non-consumable IAP "Unlock Pro" via StoreKit 2. No subscription.
- Free tier: area/window/full-screen capture, menu bar app, annotation basics, copy/save/drag-out.
- Pro tier: background/padding beautification, pinned floating screenshots, capture history, OCR, export presets.
- Deferred (not v1): scrolling capture (sandbox-hostile), cloud share links (needs backend), video/GIF recording.
- Bundle ID style: com.shafi.<name>.

## Architecture conventions
- SwiftUI menu-bar-first app (`MenuBarExtra`), no Dock icon by default (LSUIElement).
- Capture via ScreenCaptureKit (`SCScreenshotManager`); permission flow must handle Screen Recording TCC denial gracefully (deep-link to System Settings).
- OCR via Vision framework (`RecognizeTextRequest`).
- Annotation editor: SwiftUI Canvas-based, non-destructive shape list rendered over the captured image.
- Pro gating: one `ProStore` (ObservableObject / @Observable) owning StoreKit 2 entitlement state; feature checks read from it — no scattered UserDefaults flags.
- Dark-mode-first visual identity; macOS 26 Liquid Glass materials where appropriate.

## Build & verify
- The `.xcodeproj` is **generated from `project.yml` by XcodeGen** — never hand-edit the pbxproj. After adding/removing files: `xcodegen generate` (from the project root). Pre-generation SourceKit "cannot find in scope" diagnostics are noise.
- Build: `xcodebuild -scheme Hypeshot -destination 'platform=macOS' build`
- Test: `xcodebuild -scheme Hypeshot -destination 'platform=macOS,arch=arm64' test` (`arch=arm64` silences the ambiguous-destination warning)
- Smoke test: `open` the built app from DerivedData, `pgrep -x Hypeshot` after ~4s, then `pkill -x Hypeshot`.
- The project lives on an external volume (`/Volumes/Lexar External/...`) — paths contain a space; always quote.
- StoreKit testing: `Hypeshot/Hypeshot.storekit` is wired into the shared scheme's run action, so purchases work without App Store Connect.

## Signing & Screen Recording TCC (hard-won)
- **Never build with ad-hoc signing (`CODE_SIGN_IDENTITY: "-"`)**: the Screen Recording grant is bound to the code signature, and ad-hoc signatures change every rebuild — the Settings checkbox stays on but capture silently fails. Symptom: permission "granted" but `CGPreflightScreenCaptureAccess()` returns false.
- Signing is Manual with the local cert `Apple Development: Mohamed Shafi (3V5L6HA7T7)`, `DEVELOPMENT_TEAM: 2EQKU4538X`. The paren value in a cert name is a personal ID, NOT the team — the team is the cert's OU (`security find-certificate -c <name> -p | openssl x509 -noout -subject`). Automatic style fails from CLI here (no Xcode account session).
- If the grant ever gets wedged: `tccutil reset ScreenCapture com.shafi.hypeshot`, relaunch, re-grant. macOS applies the grant only at app launch — always relaunch after granting.
- Capture errors route through `CaptureController.handleCaptureFailure`, which shows the permission window on declined/stale grants instead of beeping.

## Testing
- `HypeshotTests` is a hosted unit-test target (TEST_HOST/BUNDLE_LOADER into Hypeshot.app; `GENERATE_INFOPLIST_FILE: true` is required for signing). Suite covers Models, Renderer (incl. pixel-level annotation checks and beautify canvas math: output = input + 4×padding), Exporter, HistoryStore, OCR (Vision works headlessly), ProStore.
- StoreKit purchase tests: `Product.purchase()` **hangs headlessly** even with `SKTestSession.disableDialogs = true` (waits on the confirmation sheet). Drive entitlement via `SKTestSession.buyProduct(identifier:)` instead — it exercises the `Transaction.updates` listener path. Clear the session state in `defer` so the dev machine isn't left entitled.
- Not automatable: menu-bar GUI capture flows and Screen Recording TCC (can't be granted headlessly) — verify those manually.

## Status / gaps (2026-07-04)
- v1 features implemented and building green; 31/31 tests pass. App icon in `Hypeshot/Assets.xcassets`; git repo on `main`; App Store listing draft in `AppStore/`.
- Custom capture shortcuts: `HotkeyStore` (persisted specs) + recorder UI in Settings; `HotkeyManager.pause()/resume()` must bracket any local key recording. Menu items read specs via `.hotkeyShortcut(_:)`.
- Default save folder: `SaveLocationStore` persists a security-scoped bookmark (`files.bookmarks.app-scope` entitlement); Save writes there directly, falls back to the panel when unset.
- Capture pipeline settings (`CaptureController.finish`): optional auto-save of every capture to the chosen folder (`autoSaveCaptures`), `CaptureCopyMode` (off / image / saved **file** on the clipboard; file mode implies a save and degrades to image when no folder is set), and `openEditorAfterCapture` (default on; when off the capture finishes silently with a confirmation sound). Legacy `copyAfterCapture` bool is migrated in `CaptureCopyMode.current`.
- Remaining: export-presets UI (model exists; editor uses `.standard`), App Store Connect setup + real-app screenshots for submission (listing TODOs: support/privacy URLs).

# IAP resubmission — fixing rejection 2.1(b) (Submission 29915777-6aa5-4866-a526-3d21ba358e99)

Rejected 2026-07-09 because the "Unlock Pro" IAP was never submitted for review with the app.
Fix: add review screenshot + notes to the IAP, attach it to the version, upload build 1.0 (2), resubmit.

**REJECTED AGAIN 2026-07-09** (Submission 5e128ae9-711a-47c1-b989-765220241545, version reviewed 1.0 (3)) —
same 2.1(b): the binary was updated but the IAP itself still wasn't part of the submission. On the next
attempt, verify in App Store Connect BEFORE resubmitting:
- The IAP's status is **Ready to Submit** (not Missing Metadata / Developer Action Needed). The App Review
  screenshot field is the usual blocker — it's required and separate from the store screenshots.
- The IAP is actually **attached to the version**: version page → "In-App Purchases and Subscriptions"
  section → Unlock Pro is listed. Submitting the version without this attaches nothing.
- After the rejection, the version state is "Rejected" — edit the same version, don't just upload a build.

## IAP review screenshot

Use `AppStore/screenshot-6-pro.png` (2880×1800 — meets the 1440×900 minimum for macOS).
Upload under the IAP's **App Review Information → Screenshot** field (this is reviewer-only, never shown on the store).

## IAP review notes (paste into the IAP's Review Notes field)

> "Unlock Pro" is a one-time non-consumable purchase, no account required.
> To reach it: launch Hypeshot Pro, click its icon in the macOS menu bar, then choose
> "Unlock Pro…" — the purchase window opens with the Unlock Pro — $7.99 button.
> It is also reachable from Settings. The purchase unlocks: Beautify (backgrounds/padding),
> pinned floating screenshots, capture history, Copy Text (OCR), and export presets.
> Note: the app needs the Screen Recording permission (System Settings → Privacy & Security)
> to capture; the purchase flow itself works without it.

## Steps in App Store Connect

1. **My Apps → Hypeshot Pro → Monetization → In-App Purchases → Unlock Pro** (`com.shafi.hypeshot.pro`)
   - Confirm display name, description, and price ($7.99) are set for at least one localization.
   - In **App Review Information**: upload the screenshot above and paste the review notes.
   - Save. Status should become "Ready to Submit".
2. **App Store tab → the 1.0 version page → In-App Purchases and Subscriptions** section
   (appears on the version page for a first IAP) → click + and select **Unlock Pro**.
3. Upload the new binary **1.0 (2)** (Xcode → Product → Archive → Distribute App → App Store Connect),
   select it on the version page, replacing build (1).
4. Reply to the rejection message in App Store Connect ("IAP now submitted with build 2") or just
   click **Add for Review / Resubmit**.

Build number already bumped to 2 in project.yml (CFBundleVersion + CURRENT_PROJECT_VERSION).

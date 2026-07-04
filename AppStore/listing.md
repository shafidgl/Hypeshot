# Hypeshot — Mac App Store listing

All fields ready to paste into App Store Connect. Character limits noted and verified.

## App name (30 max — 12 used)
Hypeshot Pro
(exact name "Hypeshot" is taken on the App Store; a suffixed form like "Hypeshot — Screenshot Studio" (28 chars) may also be available if the plain brand is preferred)

## Subtitle (30 max — 28 used)
Capture. Annotate. Beautify.

## Promotional text (170 max — 136 used; editable without a new build)
Grab any window, mark it up, and make it gorgeous — Hypeshot lives in your menu bar so your next great screenshot is one keystroke away.

## Description (4000 max)
Hypeshot is the fastest way from "I need a screenshot" to "that looks great."

It lives in your menu bar, out of your way, until you press ⇧⌘7. Drag over exactly what you want — or grab a window or the whole screen — and your capture opens instantly in a clean, focused editor. Mark it up, copy it, and get back to work.

CAPTURE, FREE FOREVER
• Area, window, and full-screen capture with global shortcuts (⇧⌘7 / ⇧⌘8 / ⇧⌘9)
• Pixel-perfect selection with live dimensions
• Window picker that highlights exactly what you'll get

ANNOTATE, FREE FOREVER
• Arrows, boxes, ellipses, and highlights that look sharp at any size
• Redact tool pixelates sensitive info before you share
• Text labels in any color
• Non-destructive editing — undo anything, anytime

SHARE, FREE FOREVER
• Copy to clipboard automatically after every capture
• Save as PNG or JPEG, or drag straight into Slack, mail, or your design tool

HYPESHOT PRO — ONE PURCHASE, YOURS FOREVER
Upgrade once and unlock everything. No subscription. Ever.

• Beautify: wrap captures in gorgeous gradient backgrounds with padding, rounded corners, and shadow — social-ready in one click
• Pinned screenshots: float any capture above your windows while you work from it
• Capture history: every screenshot kept and browsable, so nothing is ever lost
• Copy Text (OCR): pull the text out of any screenshot, powered by on-device Vision
• Export presets: your formats, scales, and filename templates, remembered

PRIVATE BY DESIGN
Hypeshot is sandboxed and works entirely on your Mac. No account, no cloud, no analytics, no data collection. OCR runs on-device.

Made for people who screenshot all day: developers, designers, writers, support teams, and anyone who explains things with pictures.

## Keywords (100 max — 97 used)
screenshot,capture,annotate,markup,snip,beautify,ocr,redact,screen,menubar,arrow,pin,image editor

## What's New in 1.0
Say hi to Hypeshot! Area, window, and full-screen capture; a fast annotation editor with redaction; and Pro extras: Beautify backgrounds, pinned screenshots, history, OCR, and export presets.

## Categories
- Primary: Photography (matches LSApplicationCategoryType)
- Secondary: Productivity

## Pricing
- App: Free
- In-App Purchase (non-consumable):
  - Product ID: `com.shafi.hypeshot.pro`
  - Reference name: Unlock Pro
  - Display name (30 max — 10 used): Pro Unlock
    (renamed from "Hypeshot Pro" because the app itself is now named "Hypeshot Pro" —
    an IAP with the same name as the app reads as a duplicate in the purchase sheet)
  - Description (45 max — 44 used): Beautify, pins, history, OCR, export presets
  - Price: $7.99 (Tier equivalent)

## App Privacy (App Store Connect questionnaire)
- Data collected: **None**
- All processing on-device; no third-party SDKs, no tracking.

## URLs
- Support URL: https://hypecode.app/hypeshot/support
- Marketing URL (optional): https://hypecode.app
- Privacy Policy URL: https://hypecode.app/hypeshot/privacy

## Copyright
© 2026 Shafi

## Screenshots (all 2880×1800, in this folder — real app windows via debug showcase mode)
Upload in this order:
1. `screenshot-1-annotate.png` — editor with arrow, box, highlight, redaction, and text
2. `screenshot-2-beautify.png` — the renderer's actual Beautify output (PRO)
3. `screenshot-3-history.png` — history grid with demo captures (PRO)
4. `screenshot-4-pin.png` — pinned floating screenshot (PRO)
5. `screenshot-5-workflow.png` — Settings: custom shortcuts, save folder, clipboard behavior
6. `screenshot-6-pro.png` — paywall / one-time purchase

Regenerate after UI changes: build Debug, run with `HYPESHOT_SHOWCASE=1`, then
`swift Tools/compose_shots.swift "<container>/Library/Application Support/Hypeshot/Showcase" AppStore/`.
Grant the debug build Screen Recording first so window snapshots use true pixels (toolbar icons).

## App Review notes (paste into the Review Notes field)
Hypeshot is a menu bar app (no Dock icon). After launch, look for the camera viewfinder icon in the menu bar. Screen Recording permission is required for capture; the app deep-links to System Settings and offers a relaunch if it is denied. The "Unlock Pro" purchase is a non-consumable StoreKit 2 IAP; Pro features (Beautify toggle, History, OCR, Pin) show the paywall when locked. No account or server is involved.

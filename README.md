# Vendor

Sign and install iOS apps from your own device — no computer, no App Store account, no server that sees your files.

Vendor signs `.ipa` packages with a certificate you supply (a free Apple ID identity or a third-party developer certificate) and installs them straight over the air, the same way TestFlight or an enterprise MDM would. Everything — unpacking, signing, packaging, serving the install manifest — happens on-device.

## Features

- **Browse & install** from bundled and custom app repositories, or import your own `.ipa`.
- **Sign with your own certificate** — `.p12` + `.mobileprovision`, imported and kept in Vendor's own private storage.
- **Inject tweaks** (`.dylib` / `.deb`) into a package before signing.
- **Queue multiple signs and installs** — start several, they run one after another and pick up automatically.
- **On-device install**, no cable and no third-party relay: Vendor serves the signed package to iOS itself over a local HTTPS connection.
- **English and Spanish**, switchable at any time, everywhere in the app.

## Download

Don't want to build it yourself? Every [release](https://github.com/leonardob8777-bit/Vendor/releases) carries an unsigned `Vendor.ipa` built straight from that tag — sign it with your own certificate the same way you would any package you import into Vendor.

## Requirements

- iOS 15.0 or later.
- Xcode 16+ to build.
- A signing certificate: either a free Apple ID identity (created the first time you build and run on a registered device — 7-day apps, 3 apps at a time) or a paid/third-party developer certificate.

## Building

```bash
git clone <this repo>
cd Vendor
open Vendor.xcodeproj
```

Xcode resolves the three Swift Package dependencies (see [Acknowledgments](#acknowledgments)) on first open. Set your own team under Signing & Capabilities, then build to a device — Vendor needs real hardware to sign and install anything; the simulator can only exercise the interface.

## Privacy

Not affiliated with Apple Inc. Vendor has no account system, collects no analytics, and makes no network request that isn't a plain read: every `POST` and upload path in the codebase is exactly zero. Certificates stay in Vendor's own app-support folder; passwords stay in the iOS keychain, never beside the file they unlock.

## Known limitations

- Vendor reaches your device over `*.backloop.dev`, a publicly-trusted domain whose subdomains resolve to `127.0.0.1` — this is what lets iOS accept the local install server without you configuring anything. It's a dependency Vendor doesn't control: if it goes down, on-device installs break for everyone using it, Vendor included, until a local fallback authority (already built in) is trusted once, manually, per device.
- The pinned `Zsign-Package` revision (`6ffe703`) has an uninitialized pointer in `checkRevokage`. Vendor avoids the path that triggers it; it isn't fixed at the source, since that's upstream, not Vendor's code.

## Acknowledgments

Vendor's own code is MIT-licensed (see [LICENSE](LICENSE)). It's built on:

- [Zsign-Package](https://github.com/khcrysalis/Zsign-Package) — the signing engine itself. MIT.
- [IDeviceKit](https://github.com/khcrysalis/IDeviceKit) — device-communication primitives. MIT.
- [OpenSSL](https://github.com/krzyzanowskim/OpenSSL) — Swift package wrapper. Apache 2.0.

## Links

- Telegram: https://t.me/LBsignapp
- Website: https://leonardob8777-bit.github.io/

These are the only two official channels. Anything claiming to be Vendor elsewhere isn't.

# aWolfAfterDar’s Ad Getr3kt — internal build

Run **Actions → Ad Getr3kt unsigned IPA → Run workflow** on `codex/internal-unsigned`. The initial push to that branch also starts a build if Actions is enabled for this fork. Download the `Ad-Getr3kt-unsigned-*` artifact. It contains the unsigned IPA, SHA-256 and bundle ID reference. No certificate, Apple login, Fastlane match, or App Store Connect key is used.

The workflow uses the existing `AdguardPro` scheme, its `ProApplication` metadata and Pro Safari web extension (`ADG_PRO=1`). The existing ConfigurationService already grants Pro functionality to that target. Advanced mode now defaults on for a fresh installation and remains user-controllable. Choose Debug in the workflow to build the upstream diagnostics configuration. No backend license or receipt is fabricated; hosted subscription services are not enabled by compiling local features.

Settings has an **Appearance** button. Import a background from Files (downsampled to 2048 pixels and persisted locally); remove it to restore the regular theme. The shared theme background renders the image with a light/dark overlay for readable text. Screens with their own opaque backgrounds may cover it. Switch between the original icon and three bundled alternatives. Change the in-app name there; change the Home Screen name with the workflow's `app_name` input and reinstall. iOS does not allow an app to rewrite its installed Home Screen name or install an arbitrary runtime icon using public APIs.

## Build setup and dependencies

- macOS GitHub runner and latest stable Xcode (the current project includes Icon Composer assets).
- Node 22 and Yarn Classic for the existing Safari extension build phases.
- Public DnsLibs v2.10.1 source and its NativeLibsCommon bootstrap, Conan, CMake and Ninja. The current project refers to `core.dns-libs` in a package registry. CI instead compiles a host macOS slice (for Builder) and iPhone arm64 slice, creates an xcframework and wires a local binary package into both Xcode projects. The first source build is expensive; the result is cached.
- Existing Builder target still downloads and packages default filters and database. Its nested xcodebuild also receives unsigned flags.
- Existing framework signing shell phases are skipped only when `CODE_SIGNING_ALLOWED=NO`. Other resources, copy phases and extension dependencies remain intact.
- Packaging wraps the device build in `Payload`, applies the custom name including localized overrides, adds alternate icon metadata and images, strips embedded signatures, verifies the ZIP and checks that extensions are included. It does not call signed archive export.

## Signing afterwards

The app and extensions now share one App Group resolver for preferences, logs, databases and filter files. It preserves the configured group when accessible. If re-signing changes the authorized groups, it reads group candidates from the containing app's embedded provisioning profile, sorts them consistently, and uses only a group for which iOS returns an accessible container. Extensions read the same host profile even when they have no embedded profile of their own. All targets must still be signed with a common authorized group; this does not grant missing capabilities. No user profiles or signer-specific group identifiers are built into this change. The workflow runs native Foundation regression checks for this resolution before building the app.

Sign all nested frameworks, extensions and the host app. A certificate alone does not grant capabilities: matching profiles must authorize each bundle ID, the common App Group, and the DNS/packet tunnel Network Extension entitlements. Re-signing tools that strip these capabilities can install an app whose DNS protection or shared extension storage fails. Source entitlements are preserved in the repo; `signing-reference.json` records the built bundle IDs. Workflow builds retain the upstream IDs intentionally because those IDs also occur in extension communication code.

## Validation status

Python compilation and Bash syntax checks passed. The project preparation script was exercised against copies of both actual upstream Xcode project files: both registry references and both manual signing phases were handled. Full iOS compilation, device installation, appearance rendering and network extension operation require the macOS workflow and a signed device test; they have not been established by local checks.

## Feature scope

Local Pro features follow the existing Pro target: DNS settings and encryption, custom subscriptions, advanced protection and the Pro web extension. Advanced/low-level settings are exposed through the existing advanced-mode preference. User permission is still required to enable Safari content blockers and install a VPN/DNS configuration. Incompatible build conditions such as app-versus-extension code and debug-versus-release are not all enabled simultaneously. There is no substantiated universal “enable every hidden feature” switch.

# DaguaBC

DaguaBC is a Windows-first, local basketball highlight editor. It finds likely baskets in fixed-camera footage of one hoop so you can review clips, add missed plays, tag players, and export MP4 reels.

**[Download the Windows x64 installer](https://github.com/lten44/DaguaBC/releases/download/v0.3.0/DaguaBC-0.3.0-Windows-x64-Setup.exe)** · [Release notes, source archives, and checksums](https://github.com/lten44/DaguaBC/releases/tag/v0.3.0)

## What DaguaBC adds to BHE

- **Shooter-centered portrait framing in 0.3.0.** DaguaBC builds on BHE v0.1.16's 9:16 ball-follow export. It frames the player at release, pans gently toward the rim after the shot, and holds after the basket. When the evidence links a catch to the same scoring play, the crop frames the receiver before the shot. Review the crop, pick the shooter manually, or use ball following for individual clips. [BHE v0.1.16](https://github.com/fly7632785/basketball-highlight-editor/releases/tag/v0.1.16)
- **Review and exports on Windows.** DaguaBC adds a zoomable review timeline, duplicate clip grouping, timed hoop recalibration, Chinese IME support for player tags, configurable MP4 exports, and optional 1080p analysis proxies. Final exports read the original footage.

## Special thanks to the creator of BHE

**Thank you to Jafir ([@fly7632785](https://github.com/fly7632785)) for open-sourcing [Basketball Highlight Editor (BHE)](https://github.com/fly7632785/basketball-highlight-editor).** DaguaBC is built on BHE's desktop application, analysis and review workflow, and basketball detector. Thanks also to Jafir for confirming model redistribution in [BHE issue #21](https://github.com/fly7632785/basketball-highlight-editor/issues/21#issuecomment-7090238591), to all BHE contributors, and to [EddyLL06 for the rim-check work in PR #18](https://github.com/fly7632785/basketball-highlight-editor/pull/18).

[简体中文](README.md) · [Illustrated workflow](README.md#使用流程) · [Build and run on Windows](docs/WINDOWS_SOURCE.md) · [Changelog](CHANGELOG.md)

Thanks to Jafir for adopting DaguaBC's fix for saving review decisions and player tags during preview generation in BHE v0.1.16. [Upstream PR #23](https://github.com/fly7632785/basketball-highlight-editor/pull/23)

Analysis, review, and export run locally. The optional shooter-centered mode prompts for a one-time download of the official YOLOX model, then works offline. [Model provenance](docs/MODEL_AND_DATA_LICENSES.md)

DaguaBC releases are provided under the [GNU AGPL-3.0](LICENSE). We preserve the original [BHE MIT license and copyright notice](LICENSES/BHE-MIT.txt). Fonts, branding, models, and third-party runtime dependencies retain their own terms. [Upstream attribution](NOTICE) · [Model and data provenance](docs/MODEL_AND_DATA_LICENSES.md) · [Third-party notices](docs/THIRD_PARTY_NOTICES.md)

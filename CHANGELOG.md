# Changelog

## v1.1.0

Major release.

- Rebuilt the interface around a polished native SwiftUI app shell.
- Moved import, transcription, queue, and export actions into the toolbar with clearer interaction states.
- Added responsive queue, provider, statistics, and transcript layouts that avoid clipping at narrower window sizes.
- Unified accent colors, motion behavior, launch transitions, app icon handling, and repository packaging conventions.
- Lowered the runtime requirement to macOS 12 and added universal Apple Silicon and Intel support.

## v1.0.2

Patch release.

- Added a correctly sized macOS app icon that visually shows audio transforming into text.
- Embedded the refreshed icon in the README, app bundle, and release package.

## v1.0.1

Patch release.

- Lowered runtime requirement from macOS 14+ to macOS 13+.
- Lowered build tool requirement from Xcode 16+ / Swift 6.0+ to Xcode 15+ / Swift 5.9+.
- Replaced the macOS 14-only empty-state view with a SwiftUI fallback compatible with macOS 13.
- Switched the project license to MPL-2.0.
- Aligned repository presentation and release asset naming with the other HanBangyuan8 repositories.

## v1.0.0

Initial public release.

- Native SwiftUI macOS app for audio-to-text transcription.
- Supports OpenAI-compatible audio transcription APIs.
- Supports OpenAI-compatible multimodal chat audio APIs.
- Supports custom JSON multimodal gateways with configurable response paths.
- Supports local ASR/LLM command pipelines such as whisper.cpp, mlx-whisper, faster-whisper, and custom scripts.
- Includes provider presets for OpenAI, Qwen/DashScope-style compatibility layers, Gemini-compatible gateways, local gateways, and local command runners.
- Handles multiple audio formats including MP3, WAV, M4A, FLAC, OGG, WebM, and AAC.
- Provides language hints, prompt/glossary guidance, custom HTTP headers, custom multipart fields, retries, and timeout controls.
- Persists the transcription queue and completed results between app launches.
- Exports selected or completed transcripts as TXT, Markdown, SRT, WebVTT, JSON, CSV, TSV, and HTML.
- Packages as a standalone macOS `.app` with `scripts/package-app.sh`.

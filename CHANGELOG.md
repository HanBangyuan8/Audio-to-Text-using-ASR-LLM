# Changelog

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

import Foundation

struct ProviderConfiguration: Codable, Equatable, Sendable {
    var backend: ASRBackendMode = .apiTranscriptions
    var baseURL: String = "https://api.openai.com"
    var endpointPath: String = "/v1/audio/transcriptions"
    var apiKey: String = ""
    var model: String = "gpt-4o-transcribe"
    var language: String = ""
    var prompt: String = ""
    var responseFormat: ASRResponseFormat = .verboseJSON
    var temperature: Double = 0
    var chatAudioPayload: ChatAudioPayloadMode = .inputAudio
    var customHeaders: String = ""
    var extraFields: String = ""
    var customJSONTemplate: String = ""
    var responseTextPath: String = ""
    var localCommandTemplate: String = ""

    var resolvedEndpoint: URL? {
        guard let base = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        let normalizedPath = endpointPath.hasPrefix("/") ? endpointPath : "/" + endpointPath
        return URL(string: normalizedPath, relativeTo: base)?.absoluteURL
    }
}

enum ASRBackendMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case apiTranscriptions
    case apiChatAudio
    case apiCustomJSON
    case localCommand

    var id: String { rawValue }

    var label: String {
        switch self {
        case .apiTranscriptions: "API: Audio Transcriptions"
        case .apiChatAudio: "API: Chat Audio"
        case .apiCustomJSON: "API: Custom JSON"
        case .localCommand: "Local: Command"
        }
    }

    var recommendedEndpointPath: String {
        switch self {
        case .apiTranscriptions: "/v1/audio/transcriptions"
        case .apiChatAudio: "/v1/chat/completions"
        case .apiCustomJSON: "/v1/chat/completions"
        case .localCommand: ""
        }
    }
}

enum ChatAudioPayloadMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case inputAudio
    case audioURLDataURL

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inputAudio: "input_audio"
        case .audioURLDataURL: "audio_url data URL"
        }
    }
}

enum ASRResponseFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case json
    case text
    case srt
    case verboseJSON = "verbose_json"
    case vtt

    var id: String { rawValue }

    var label: String {
        switch self {
        case .json: "JSON"
        case .text: "Text"
        case .srt: "SRT"
        case .verboseJSON: "Verbose JSON"
        case .vtt: "VTT"
        }
    }
}

enum TextExportFormat: String, CaseIterable, Identifiable, Sendable {
    case txt
    case markdown
    case srt
    case vtt
    case json
    case csv
    case tsv
    case html

    var id: String { rawValue }

    var label: String {
        switch self {
        case .txt: "TXT"
        case .markdown: "Markdown"
        case .srt: "SRT"
        case .vtt: "WebVTT"
        case .json: "JSON"
        case .csv: "CSV"
        case .tsv: "TSV"
        case .html: "HTML"
        }
    }

    var fileExtension: String {
        switch self {
        case .txt: "txt"
        case .markdown: "md"
        case .srt: "srt"
        case .vtt: "vtt"
        case .json: "json"
        case .csv: "csv"
        case .tsv: "tsv"
        case .html: "html"
        }
    }
}

struct ProviderPreset: Identifiable, Sendable {
    var id: String { name }
    var name: String
    var configuration: ProviderConfiguration
}

enum ProviderPresets {
    static let all: [ProviderPreset] = [
        ProviderPreset(
            name: "OpenAI Transcribe",
            configuration: ProviderConfiguration(
                backend: .apiTranscriptions,
                baseURL: "https://api.openai.com",
                endpointPath: "/v1/audio/transcriptions",
                model: "gpt-4o-transcribe",
                responseFormat: .verboseJSON
            )
        ),
        ProviderPreset(
            name: "OpenAI Whisper Compatible",
            configuration: ProviderConfiguration(
                backend: .apiTranscriptions,
                baseURL: "https://api.openai.com",
                endpointPath: "/v1/audio/transcriptions",
                model: "whisper-1",
                responseFormat: .verboseJSON
            )
        ),
        ProviderPreset(
            name: "Local OpenAI Gateway",
            configuration: ProviderConfiguration(
                backend: .apiTranscriptions,
                baseURL: "http://127.0.0.1:8000",
                endpointPath: "/v1/audio/transcriptions",
                model: "whisper-large-v3",
                responseFormat: .verboseJSON
            )
        ),
        ProviderPreset(
            name: "Qwen / DashScope Compatible",
            configuration: ProviderConfiguration(
                backend: .apiTranscriptions,
                baseURL: "https://dashscope.aliyuncs.com/compatible-mode",
                endpointPath: "/v1/audio/transcriptions",
                model: "qwen-audio-asr",
                responseFormat: .verboseJSON
            )
        ),
        ProviderPreset(
            name: "Gemini Gateway Chat Audio",
            configuration: ProviderConfiguration(
                backend: .apiChatAudio,
                baseURL: "http://127.0.0.1:8000",
                endpointPath: "/v1/chat/completions",
                model: "gemini-2.5-flash",
                chatAudioPayload: .audioURLDataURL,
                responseTextPath: "choices.0.message.content"
            )
        ),
        ProviderPreset(
            name: "Custom JSON Multimodal",
            configuration: ProviderConfiguration(
                backend: .apiCustomJSON,
                baseURL: "http://127.0.0.1:8000",
                endpointPath: "/v1/chat/completions",
                model: "your-audio-model",
                customJSONTemplate: ProviderConfiguration.defaultCustomJSONTemplate,
                responseTextPath: "choices.0.message.content"
            )
        ),
        ProviderPreset(
            name: "whisper.cpp",
            configuration: ProviderConfiguration(
                backend: .localCommand,
                model: "/path/to/ggml-large-v3.bin",
                localCommandTemplate: "whisper-cli -m {model} -f {audio} -l {language} -otxt -osrt -of {outputBase}"
            )
        ),
        ProviderPreset(
            name: "mlx-whisper",
            configuration: ProviderConfiguration(
                backend: .localCommand,
                model: "mlx-community/whisper-large-v3-mlx",
                localCommandTemplate: "mlx_whisper {audio} --model {model} --language {language} > {output}"
            )
        ),
        ProviderPreset(
            name: "faster-whisper script",
            configuration: ProviderConfiguration(
                backend: .localCommand,
                model: "large-v3",
                localCommandTemplate: "python3 ~/asr/transcribe.py --audio {audio} --model {model} --language {language} --prompt {prompt} > {output}"
            )
        )
    ]
}

extension ProviderConfiguration {
    static let defaultCustomJSONTemplate = """
    {
      "model": "{model}",
      "temperature": {temperature},
      "messages": [
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text": "{instruction}"
            },
            {
              "type": "audio_url",
              "audio_url": {
                "url": "{audioDataURL}"
              }
            }
          ]
        }
      ]
    }
    """
}

struct AudioFile: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL

    var name: String { url.lastPathComponent }
    var path: String { url.path(percentEncoded: false) }
}

struct TranscriptSegment: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var start: TimeInterval
    var end: TimeInterval
    var text: String

    enum CodingKeys: String, CodingKey {
        case start
        case end
        case text
    }
}

struct TranscriptionResult: Codable, Hashable, Sendable {
    var sourceFileName: String
    var model: String
    var text: String
    var rawResponse: String
    var segments: [TranscriptSegment]
    var createdAt: Date = .now
}

struct TranscriptionRecord: Identifiable, Hashable, Sendable {
    let id = UUID()
    var file: AudioFile
    var result: TranscriptionResult?
    var status: TranscriptionStatus = .queued
    var errorMessage: String?
}

enum TranscriptionStatus: Hashable, Sendable {
    case queued
    case running
    case complete
    case failed
    case canceled

    var label: String {
        switch self {
        case .queued: "Queued"
        case .running: "Running"
        case .complete: "Complete"
        case .failed: "Failed"
        case .canceled: "Canceled"
        }
    }
}

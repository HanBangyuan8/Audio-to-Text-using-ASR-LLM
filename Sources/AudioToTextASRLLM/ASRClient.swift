import Foundation
import UniformTypeIdentifiers

enum ASRClientError: LocalizedError {
    case invalidEndpoint
    case unreadableAudio(URL)
    case invalidResponse
    case requestFailed(status: Int, body: String)
    case missingText
    case missingLocalCommand
    case invalidRetryCount
    case localCommandFailed(status: Int32, output: String)
    case localCommandTimedOut(seconds: Double)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            "The transcription endpoint URL is invalid."
        case .unreadableAudio(let url):
            "Could not read audio file: \(url.lastPathComponent)"
        case .invalidResponse:
            "The transcription service returned an invalid response."
        case .requestFailed(let status, let body):
            "Transcription request failed with HTTP \(status): \(body)"
        case .missingText:
            "The transcription response did not include recognized text."
        case .missingLocalCommand:
            "Local command template is empty."
        case .invalidRetryCount:
            "Retry count must be zero or greater."
        case .localCommandFailed(let status, let output):
            "Local command failed with exit code \(status): \(output)"
        case .localCommandTimedOut(let seconds):
            "Local command timed out after \(Int(seconds)) seconds."
        }
    }
}

struct ASRClient {
    func transcribe(fileURL: URL, configuration: ProviderConfiguration) async throws -> TranscriptionResult {
        guard configuration.maxRetries >= 0 else {
            throw ASRClientError.invalidRetryCount
        }

        var lastError: Error?
        let attempts = configuration.maxRetries + 1
        for attempt in 1...attempts {
            do {
                return try await transcribeOnce(fileURL: fileURL, configuration: configuration)
            } catch {
                lastError = error
                if attempt < attempts && shouldRetry(error) {
                    let delay = UInt64(min(4.0, pow(2.0, Double(attempt - 1))) * 1_000_000_000)
                    try await Task.sleep(nanoseconds: delay)
                    continue
                }
                throw error
            }
        }

        throw lastError ?? ASRClientError.invalidResponse
    }

    private func transcribeOnce(fileURL: URL, configuration: ProviderConfiguration) async throws -> TranscriptionResult {
        switch configuration.backend {
        case .apiTranscriptions:
            return try await transcribeWithMultipartAPI(fileURL: fileURL, configuration: configuration)
        case .apiChatAudio:
            return try await transcribeWithChatAudioAPI(fileURL: fileURL, configuration: configuration)
        case .apiCustomJSON:
            return try await transcribeWithCustomJSONAPI(fileURL: fileURL, configuration: configuration)
        case .localCommand:
            return try await Task.detached {
                try LocalASRRunner.transcribe(fileURL: fileURL, configuration: configuration)
            }.value
        }
    }

    private func shouldRetry(_ error: Error) -> Bool {
        if error is CancellationError {
            return false
        }

        if case ASRClientError.requestFailed(let status, _) = error {
            return status == 408 || status == 409 || status == 425 || status == 429 || (500...599).contains(status)
        }

        if case ASRClientError.localCommandFailed = error {
            return false
        }

        return true
    }

    private func transcribeWithMultipartAPI(fileURL: URL, configuration: ProviderConfiguration) async throws -> TranscriptionResult {
        guard let endpoint = configuration.resolvedEndpoint else {
            throw ASRClientError.invalidEndpoint
        }

        guard let audioData = try? Data(contentsOf: fileURL) else {
            throw ASRClientError.unreadableAudio(fileURL)
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = normalizedTimeout(configuration.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("AudioToTextASRLLM/1.0", forHTTPHeaderField: "User-Agent")
        applyCommonHeaders(to: &request, configuration: configuration)

        let apiKey = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let fields = buildFields(configuration: configuration)
        let body = MultipartFormData(boundary: boundary)
            .addingFields(fields)
            .addingFile(
                fieldName: "file",
                fileName: fileURL.lastPathComponent,
                mimeType: mimeType(for: fileURL),
                data: audioData
            )
            .finalized()

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ASRClientError.invalidResponse
        }

        let responseBody = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ASRClientError.requestFailed(status: httpResponse.statusCode, body: responseBody)
        }

        return try parseResponse(
            data: data,
            rawResponse: responseBody,
            fileName: fileURL.lastPathComponent,
            model: configuration.model,
            responseFormat: configuration.responseFormat
        )
    }

    private func transcribeWithChatAudioAPI(fileURL: URL, configuration: ProviderConfiguration) async throws -> TranscriptionResult {
        guard let endpoint = configuration.resolvedEndpoint else {
            throw ASRClientError.invalidEndpoint
        }

        guard let audioData = try? Data(contentsOf: fileURL) else {
            throw ASRClientError.unreadableAudio(fileURL)
        }

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = normalizedTimeout(configuration.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("AudioToTextASRLLM/1.0", forHTTPHeaderField: "User-Agent")
        applyCommonHeaders(to: &request, configuration: configuration)

        let apiKey = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let instruction = chatInstruction(configuration: configuration)
        let audioPart: [String: Any] = switch configuration.chatAudioPayload {
        case .inputAudio:
            [
                "type": "input_audio",
                "input_audio": [
                    "data": audioData.base64EncodedString(),
                    "format": fileURL.pathExtension.lowercased()
                ]
            ]
        case .audioURLDataURL:
            [
                "type": "audio_url",
                "audio_url": [
                    "url": dataURL(audioData: audioData, mimeType: mimeType(for: fileURL))
                ]
            ]
        }

        let payload: [String: Any] = [
            "model": configuration.model,
            "temperature": configuration.temperature,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": instruction
                        ],
                        audioPart
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ASRClientError.invalidResponse
        }

        let responseBody = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ASRClientError.requestFailed(status: httpResponse.statusCode, body: responseBody)
        }

        let text = try parseResponseText(data: data, configuredPath: configuration.responseTextPath)
        return TranscriptionResult(
            sourceFileName: fileURL.lastPathComponent,
            model: configuration.model,
            text: text,
            rawResponse: responseBody,
            segments: []
        )
    }

    private func transcribeWithCustomJSONAPI(fileURL: URL, configuration: ProviderConfiguration) async throws -> TranscriptionResult {
        guard let endpoint = configuration.resolvedEndpoint else {
            throw ASRClientError.invalidEndpoint
        }

        guard let audioData = try? Data(contentsOf: fileURL) else {
            throw ASRClientError.unreadableAudio(fileURL)
        }

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = normalizedTimeout(configuration.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("AudioToTextASRLLM/1.0", forHTTPHeaderField: "User-Agent")
        applyCommonHeaders(to: &request, configuration: configuration)

        let apiKey = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let template = configuration.customJSONTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ProviderConfiguration.defaultCustomJSONTemplate
            : configuration.customJSONTemplate

        let body = renderJSONTemplate(
            template,
            fileURL: fileURL,
            audioData: audioData,
            configuration: configuration
        )

        guard let requestBody = body.data(using: .utf8) else {
            throw ASRClientError.invalidResponse
        }

        request.httpBody = requestBody
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ASRClientError.invalidResponse
        }

        let responseBody = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ASRClientError.requestFailed(status: httpResponse.statusCode, body: responseBody)
        }

        let text = try parseResponseText(data: data, configuredPath: configuration.responseTextPath)
        return TranscriptionResult(
            sourceFileName: fileURL.lastPathComponent,
            model: configuration.model,
            text: text,
            rawResponse: responseBody,
            segments: []
        )
    }

    private func buildFields(configuration: ProviderConfiguration) -> [String: String] {
        var fields: [String: String] = [
            "model": configuration.model,
            "response_format": configuration.responseFormat.rawValue,
            "temperature": String(format: "%.2f", configuration.temperature)
        ]

        let language = configuration.language.trimmingCharacters(in: .whitespacesAndNewlines)
        if !language.isEmpty {
            fields["language"] = language
        }

        let prompt = configuration.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prompt.isEmpty {
            fields["prompt"] = prompt
        }

        for (key, value) in parseExtraFields(configuration.extraFields) {
            fields[key] = value
        }

        return fields
    }

    private func parseExtraFields(_ source: String) -> [String: String] {
        source
            .split(whereSeparator: \.isNewline)
            .reduce(into: [String: String]()) { result, line in
                let pair = line.split(separator: "=", maxSplits: 1).map(String.init)
                guard pair.count == 2 else { return }
                let key = pair[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = pair[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty {
                    result[key] = value
                }
            }
    }

    private func applyCommonHeaders(to request: inout URLRequest, configuration: ProviderConfiguration) {
        for (key, value) in parseHeaders(configuration.customHeaders) {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    private func parseHeaders(_ source: String) -> [String: String] {
        source
            .split(whereSeparator: \.isNewline)
            .reduce(into: [String: String]()) { result, line in
                let rawLine = String(line)
                let pair = rawLine.contains(":")
                    ? rawLine.split(separator: ":", maxSplits: 1).map(String.init)
                    : rawLine.split(separator: "=", maxSplits: 1).map(String.init)
                guard pair.count == 2 else { return }
                let key = pair[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = pair[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty {
                    result[key] = value
                }
            }
    }

    private func chatInstruction(configuration: ProviderConfiguration) -> String {
        var instruction = "Transcribe the attached audio with very high accuracy. Preserve the spoken language, punctuation, paragraph breaks, names, numbers, and domain terms. Return only the transcript text."

        let language = configuration.language.trimmingCharacters(in: .whitespacesAndNewlines)
        if !language.isEmpty {
            instruction += "\nLanguage hint: \(language)."
        }

        let prompt = configuration.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prompt.isEmpty {
            instruction += "\nUser guidance and glossary:\n\(prompt)"
        }

        return instruction
    }

    private func parseResponseText(data: Data, configuredPath: String) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data)
        let path = configuredPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty, let value = value(at: path, in: json) {
            let text = stringValue(value).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw ASRClientError.missingText }
            return text
        }

        if let root = json as? [String: Any], let text = root["text"] as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw ASRClientError.missingText }
            return trimmed
        }

        guard let root = json as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any] else {
            throw ASRClientError.invalidResponse
        }

        if let content = message["content"] as? String {
            let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw ASRClientError.missingText }
            return text
        }

        if let parts = message["content"] as? [[String: Any]] {
            let text = parts.compactMap { part in
                part["text"] as? String
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw ASRClientError.missingText }
            return text
        }

        throw ASRClientError.missingText
    }

    private func value(at path: String, in json: Any) -> Any? {
        var current: Any? = json
        for part in path.split(separator: ".").map(String.init) {
            if let dictionary = current as? [String: Any] {
                current = dictionary[part]
            } else if let array = current as? [Any], let index = Int(part), array.indices.contains(index) {
                current = array[index]
            } else {
                return nil
            }
        }
        return current
    }

    private func stringValue(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }

        if let parts = value as? [[String: Any]] {
            return parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
        }

        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value),
           let string = String(data: data, encoding: .utf8) {
            return string
        }

        return "\(value)"
    }

    private func renderJSONTemplate(
        _ template: String,
        fileURL: URL,
        audioData: Data,
        configuration: ProviderConfiguration
    ) -> String {
        let mimeType = mimeType(for: fileURL)
        let replacements: [String: String] = [
            "{model}": jsonEscaped(configuration.model),
            "{temperature}": String(format: "%.2f", configuration.temperature),
            "{language}": jsonEscaped(configuration.language),
            "{prompt}": jsonEscaped(configuration.prompt),
            "{instruction}": jsonEscaped(chatInstruction(configuration: configuration)),
            "{filename}": jsonEscaped(fileURL.lastPathComponent),
            "{mimeType}": jsonEscaped(mimeType),
            "{audioBase64}": audioData.base64EncodedString(),
            "{audioDataURL}": dataURL(audioData: audioData, mimeType: mimeType)
        ]

        return replacements.reduce(template) { output, replacement in
            output.replacingOccurrences(of: replacement.key, with: replacement.value)
        }
    }

    private func dataURL(audioData: Data, mimeType: String) -> String {
        "data:\(mimeType);base64,\(audioData.base64EncodedString())"
    }

    private func jsonEscaped(_ value: String) -> String {
        let data = try? JSONEncoder().encode(value)
        let quoted = data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        return String(quoted.dropFirst().dropLast())
    }

    private func parseResponse(
        data: Data,
        rawResponse: String,
        fileName: String,
        model: String,
        responseFormat: ASRResponseFormat
    ) throws -> TranscriptionResult {
        switch responseFormat {
        case .text, .srt, .vtt:
            let text = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw ASRClientError.missingText }
            return TranscriptionResult(sourceFileName: fileName, model: model, text: text, rawResponse: rawResponse, segments: [])
        case .json, .verboseJSON:
            let decoded = try JSONDecoder().decode(FlexibleTranscriptionResponse.self, from: data)
            guard !decoded.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ASRClientError.missingText
            }

            return TranscriptionResult(
                sourceFileName: fileName,
                model: model,
                text: decoded.text,
                rawResponse: rawResponse,
                segments: decoded.segments
            )
        }
    }

    private func mimeType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension),
           let mimeType = type.preferredMIMEType {
            return mimeType
        }

        return switch url.pathExtension.lowercased() {
        case "mp3": "audio/mpeg"
        case "wav": "audio/wav"
        case "m4a": "audio/mp4"
        case "flac": "audio/flac"
        case "ogg", "oga": "audio/ogg"
        case "webm": "audio/webm"
        case "aac": "audio/aac"
        default: "application/octet-stream"
        }
    }

    private func normalizedTimeout(_ timeout: Double) -> TimeInterval {
        max(30, min(timeout, 86_400))
    }
}

private enum LocalASRRunner {
    static func transcribe(fileURL: URL, configuration: ProviderConfiguration) throws -> TranscriptionResult {
        let template = configuration.localCommandTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !template.isEmpty else {
            throw ASRClientError.missingLocalCommand
        }

        let outputBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioToTextASRLLM-\(UUID().uuidString)")

        let command = renderCommand(
            template: template,
            fileURL: fileURL,
            outputBase: outputBase,
            configuration: configuration
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        try waitForProcess(process, timeout: configuration.requestTimeout)

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw ASRClientError.localCommandFailed(status: process.terminationStatus, output: output)
        }

        let text = try readLocalOutput(outputBase: outputBase, stdout: output)
        return TranscriptionResult(
            sourceFileName: fileURL.lastPathComponent,
            model: configuration.model.isEmpty ? "local-command" : configuration.model,
            text: text,
            rawResponse: output,
            segments: []
        )
    }

    private static func renderCommand(
        template: String,
        fileURL: URL,
        outputBase: URL,
        configuration: ProviderConfiguration
    ) -> String {
        template
            .replacingOccurrences(of: "{audio}", with: shellQuote(fileURL.path(percentEncoded: false)))
            .replacingOccurrences(of: "{outputBase}", with: shellQuote(outputBase.path(percentEncoded: false)))
            .replacingOccurrences(of: "{output}", with: shellQuote(outputBase.appendingPathExtension("txt").path(percentEncoded: false)))
            .replacingOccurrences(of: "{model}", with: shellQuote(configuration.model))
            .replacingOccurrences(of: "{language}", with: shellQuote(configuration.language))
            .replacingOccurrences(of: "{prompt}", with: shellQuote(configuration.prompt))
    }

    private static func readLocalOutput(outputBase: URL, stdout: String) throws -> String {
        let candidates = ["txt", "md", "srt", "vtt", "json"].map {
            outputBase.appendingPathExtension($0)
        }

        for url in candidates where FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            let text = try String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return text
            }
        }

        let text = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw ASRClientError.missingText
        }
        return text
    }

    private static func waitForProcess(_ process: Process, timeout: Double) throws {
        let normalizedTimeout = max(30, min(timeout, 86_400))
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + normalizedTimeout) == .timedOut {
            process.terminate()
            throw ASRClientError.localCommandTimedOut(seconds: normalizedTimeout)
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

private struct FlexibleTranscriptionResponse: Decodable {
    var text: String
    var segments: [TranscriptSegment]

    enum CodingKeys: String, CodingKey {
        case text
        case segments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        segments = try container.decodeIfPresent([TranscriptSegment].self, forKey: .segments) ?? []
    }
}

private struct MultipartFormData {
    private let boundary: String
    private var data = Data()

    init(boundary: String) {
        self.boundary = boundary
    }

    func addingFields(_ fields: [String: String]) -> MultipartFormData {
        var copy = self
        for key in fields.keys.sorted() {
            guard let value = fields[key] else { continue }
            copy.appendString("--\(boundary)\r\n")
            copy.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            copy.appendString("\(value)\r\n")
        }
        return copy
    }

    func addingFile(fieldName: String, fileName: String, mimeType: String, data fileData: Data) -> MultipartFormData {
        var copy = self
        copy.appendString("--\(boundary)\r\n")
        copy.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        copy.appendString("Content-Type: \(mimeType)\r\n\r\n")
        copy.data.append(fileData)
        copy.appendString("\r\n")
        return copy
    }

    func finalized() -> Data {
        var copy = self
        copy.appendString("--\(boundary)--\r\n")
        return copy.data
    }

    private mutating func appendString(_ string: String) {
        data.append(Data(string.utf8))
    }
}

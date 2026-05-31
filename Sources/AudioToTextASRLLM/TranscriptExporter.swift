import Foundation

enum TranscriptExporter {
    static func render(_ result: TranscriptionResult, as format: TextExportFormat) throws -> String {
        switch format {
        case .txt:
            return result.text
        case .markdown:
            return markdown(result)
        case .srt:
            return srt(result)
        case .vtt:
            return vtt(result)
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(result)
            return String(decoding: data, as: UTF8.self)
        case .csv:
            return csv(result)
        case .tsv:
            return tsv(result)
        case .html:
            return html(result)
        }
    }

    private static func markdown(_ result: TranscriptionResult) -> String {
        var output = """
        # \(result.sourceFileName)

        - Model: \(result.model)
        - Created: \(result.createdAt.formatted(date: .abbreviated, time: .standard))

        ## Transcript

        \(result.text)
        """

        if !result.segments.isEmpty {
            output += "\n\n## Segments\n\n"
            for segment in result.segments {
                output += "- `\(timestamp(segment.start)) - \(timestamp(segment.end))` \(segment.text)\n"
            }
        }

        return output
    }

    private static func srt(_ result: TranscriptionResult) -> String {
        let segments = normalizedSegments(result)
        return segments.enumerated().map { index, segment in
            """
            \(index + 1)
            \(srtTimestamp(segment.start)) --> \(srtTimestamp(segment.end))
            \(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))
            """
        }
        .joined(separator: "\n\n")
    }

    private static func vtt(_ result: TranscriptionResult) -> String {
        let cues = normalizedSegments(result).map { segment in
            """
            \(vttTimestamp(segment.start)) --> \(vttTimestamp(segment.end))
            \(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))
            """
        }
        .joined(separator: "\n\n")

        return "WEBVTT\n\n\(cues)"
    }

    private static func csv(_ result: TranscriptionResult) -> String {
        var rows = ["index,start,end,text"]
        for (index, segment) in normalizedSegments(result).enumerated() {
            rows.append([
                String(index + 1),
                timestamp(segment.start),
                timestamp(segment.end),
                csvEscape(segment.text)
            ].joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    private static func tsv(_ result: TranscriptionResult) -> String {
        var rows = ["index\tstart\tend\ttext"]
        for (index, segment) in normalizedSegments(result).enumerated() {
            rows.append([
                String(index + 1),
                timestamp(segment.start),
                timestamp(segment.end),
                segment.text.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
            ].joined(separator: "\t"))
        }
        return rows.joined(separator: "\n")
    }

    private static func html(_ result: TranscriptionResult) -> String {
        let paragraphs = result.text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "<p>\(htmlEscape(String($0)))</p>" }
            .joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <title>\(htmlEscape(result.sourceFileName))</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; line-height: 1.6; max-width: 860px; margin: 48px auto; padding: 0 24px; }
            h1 { font-size: 28px; }
            .meta { color: #666; font-size: 14px; }
            .segment { display: grid; grid-template-columns: 140px 1fr; gap: 16px; margin: 8px 0; }
            time { color: #666; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px; }
          </style>
        </head>
        <body>
          <h1>\(htmlEscape(result.sourceFileName))</h1>
          <p class="meta">Model: \(htmlEscape(result.model))</p>
          \(paragraphs)
          \(htmlSegments(result))
        </body>
        </html>
        """
    }

    private static func htmlSegments(_ result: TranscriptionResult) -> String {
        guard !result.segments.isEmpty else { return "" }

        let rows = result.segments.map { segment in
            """
            <div class="segment"><time>\(timestamp(segment.start)) - \(timestamp(segment.end))</time><span>\(htmlEscape(segment.text))</span></div>
            """
        }
        .joined(separator: "\n")

        return "<h2>Segments</h2>\n\(rows)"
    }

    private static func normalizedSegments(_ result: TranscriptionResult) -> [TranscriptSegment] {
        if !result.segments.isEmpty {
            return result.segments
        }

        return [TranscriptSegment(start: 0, end: 0, text: result.text)]
    }

    private static func srtTimestamp(_ seconds: TimeInterval) -> String {
        timestamp(seconds, decimalSeparator: ",")
    }

    private static func vttTimestamp(_ seconds: TimeInterval) -> String {
        timestamp(seconds, decimalSeparator: ".")
    }

    private static func timestamp(_ seconds: TimeInterval, decimalSeparator: String = ".") -> String {
        let clamped = max(0, seconds)
        let hours = Int(clamped / 3600)
        let minutes = Int(clamped.truncatingRemainder(dividingBy: 3600) / 60)
        let wholeSeconds = Int(clamped.truncatingRemainder(dividingBy: 60))
        let milliseconds = Int((clamped - floor(clamped)) * 1000)
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, wholeSeconds, decimalSeparator, milliseconds)
    }

    private static func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    private static func htmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

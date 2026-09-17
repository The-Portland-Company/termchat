import Foundation

/// Decoded view of Claude Code's `--output-format stream-json` line protocol.
/// Ported from JarvisAgent/JarvisCore, plus partial-message (delta) support.
enum StreamEvent {
    case initialized(sessionID: String)
    case textDelta(String)
    case textBlock(String)
    case toolUse(name: String)
    case finished(result: String?, isError: Bool)
    case other

    static func parse(_ line: String) -> StreamEvent {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return .other }

        switch type {
        case "system":
            if (obj["subtype"] as? String) == "init", let sid = obj["session_id"] as? String {
                return .initialized(sessionID: sid)
            }
            return .other

        case "stream_event":
            // Raw Anthropic SSE event wrapped by the CLI (--include-partial-messages).
            if let ev = obj["event"] as? [String: Any],
               ev["type"] as? String == "content_block_delta",
               let delta = ev["delta"] as? [String: Any],
               delta["type"] as? String == "text_delta",
               let t = delta["text"] as? String {
                return .textDelta(t)
            }
            return .other

        case "assistant":
            if let msg = obj["message"] as? [String: Any],
               let content = msg["content"] as? [[String: Any]] {
                for block in content {
                    if block["type"] as? String == "tool_use", let name = block["name"] as? String {
                        return .toolUse(name: name)
                    }
                    if block["type"] as? String == "text", let t = block["text"] as? String {
                        return .textBlock(t)
                    }
                }
            }
            return .other

        case "result":
            return .finished(result: obj["result"] as? String,
                             isError: (obj["is_error"] as? Bool) ?? false)

        default:
            return .other
        }
    }
}

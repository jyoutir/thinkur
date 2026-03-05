import Foundation

/// Encode a value to pretty-printed JSON, returning "[]" on failure.
func encodeJSON<T: Encodable>(_ value: T) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(value),
          let str = String(data: data, encoding: .utf8) else {
        return "[]"
    }
    return str
}

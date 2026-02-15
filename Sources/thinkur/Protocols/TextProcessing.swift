import Foundation

protocol TextProcessor {
    var name: String { get }
    func process(_ text: String, context: ProcessingContext) -> String
}

struct ProcessingContext {
    let frontmostAppBundleID: String
    let frontmostAppName: String
    let wordTimings: [WordTimingInfo]
    let appStyle: AppStyle
}

struct WordTimingInfo {
    let word: String
    let start: Float
    let end: Float
}

enum AppStyle {
    case casual
    case formal
    case code
    case standard
}

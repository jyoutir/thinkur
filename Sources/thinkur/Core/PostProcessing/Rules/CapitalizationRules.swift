import Foundation

enum CapitalizationRules {
    // MARK: - Supplementary Proper Nouns (NLTagger often misses these)

    static let supplementaryProperNouns: Set<String> = [
        // Tech brands
        "google", "apple", "microsoft", "amazon", "facebook", "meta",
        "twitter", "instagram", "snapchat", "tiktok", "spotify",
        "netflix", "uber", "airbnb", "slack", "zoom", "tesla",
        "nvidia", "intel", "amd", "samsung", "sony", "nintendo",
        "adobe", "oracle", "salesforce", "shopify", "stripe",
        "dropbox", "pinterest", "twitch", "reddit", "linkedin",
        // Programming languages & frameworks
        "javascript", "typescript", "python", "swift", "kotlin",
        "react", "angular", "vue", "node", "django", "flask",
        "docker", "kubernetes", "github", "gitlab", "jira",
        "rust", "golang", "ruby", "scala", "haskell", "elixir",
        "flutter", "electron", "webpack", "vite", "nextjs",
        // Days of week
        "monday", "tuesday", "wednesday", "thursday", "friday",
        "saturday", "sunday",
        // Months
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december",
        // Other
        "siri", "alexa", "cortana", "copilot", "chatgpt",
    ]

    // MARK: - Safe Acronyms (always uppercase — not common English words)

    static let safeAcronyms: Set<String> = [
        "api", "url", "html", "css", "sql", "json", "xml", "csv",
        "pdf", "png", "jpg", "gif", "svg", "http", "https",
        "ftp", "ssh", "ssl", "tls", "dns", "tcp", "udp",
        "vpn", "cdn", "aws", "gcp", "sdk", "ide", "cli", "gui",
        "ram", "rom", "cpu", "gpu", "ssd", "hdd", "faq",
        "eta", "asap", "fyi", "btw", "imo", "ceo", "cto",
        "cfo", "coo", "llm", "gpt", "nlp", "nato", "atm",
        "rsvp", "diy", "iot", "nft", "dao", "defi",
        "usb", "hdmi", "nfc", "gps", "led", "lcd",
        "crm", "erp", "saas", "paas", "iaas",
        "seo", "sem", "roi", "kpi", "mvp",
        "jwt", "oauth", "smtp", "imap", "pop",
        "yaml", "toml", "rgba", "cmyk",
    ]

    // MARK: - Context-Dependent Acronyms

    static let contextAcronyms: [String: ContextAcronymInfo] = [
        "am": ContextAcronymInfo(
            acronymContextPattern: #"(?i)\b\d{1,2}\s+am\b"#,
            isCommonWord: true
        ),
        "pm": ContextAcronymInfo(
            acronymContextPattern: #"(?i)\b\d{1,2}\s+pm\b"#,
            isCommonWord: false
        ),
        "us": ContextAcronymInfo(
            acronymContextPattern: #"(?i)\b(the|in|from)\s+us\b"#,
            isCommonWord: true
        ),
        "it": ContextAcronymInfo(
            acronymContextPattern: #"(?i)\bit\s+(department|team|support|infrastructure|manager|director|admin)\b"#,
            isCommonWord: true
        ),
        "hr": ContextAcronymInfo(
            acronymContextPattern: #"(?i)\bhr\s+(department|team|manager|director|policy|meeting)\b"#,
            isCommonWord: false
        ),
        "ai": ContextAcronymInfo(
            acronymContextPattern: #"(?i)\bai\s+(model|system|tool|assistant|generated|powered)\b"#,
            isCommonWord: false
        ),
        "tv": ContextAcronymInfo(
            acronymContextPattern: nil,
            isCommonWord: false
        ),
        "dj": ContextAcronymInfo(
            acronymContextPattern: nil,
            isCommonWord: false
        ),
        "vp": ContextAcronymInfo(
            acronymContextPattern: nil,
            isCommonWord: false
        ),
        "pr": ContextAcronymInfo(
            acronymContextPattern: #"(?i)\bpr\s+(team|department|agency|campaign|strategy|firm|review|request)\b"#,
            isCommonWord: false
        ),
        "id": ContextAcronymInfo(
            acronymContextPattern: #"(?i)\b(user|employee|student|account|session|transaction|unique)\s+id\b"#,
            isCommonWord: true
        ),
        "ok": ContextAcronymInfo(
            acronymContextPattern: nil,
            isCommonWord: true
        ),
    ]

    struct ContextAcronymInfo {
        let acronymContextPattern: String?
        let isCommonWord: Bool
    }

    // MARK: - Special Casing (brand names with non-standard capitalization)

    static let specialCasing: [String: String] = [
        "iphone": "iPhone",
        "ipad": "iPad",
        "imac": "iMac",
        "ipod": "iPod",
        "ios": "iOS",
        "icloud": "iCloud",
        "imessage": "iMessage",
        "macos": "macOS",
        "tvos": "tvOS",
        "watchos": "watchOS",
        "visionos": "visionOS",
        "ipados": "iPadOS",
        "xcode": "Xcode",
        "swiftui": "SwiftUI",
        "uikit": "UIKit",
        "appkit": "AppKit",
        "github": "GitHub",
        "gitlab": "GitLab",
        "linkedin": "LinkedIn",
        "youtube": "YouTube",
        "javascript": "JavaScript",
        "typescript": "TypeScript",
        "postgresql": "PostgreSQL",
        "mysql": "MySQL",
        "mongodb": "MongoDB",
        "graphql": "GraphQL",
        "nodejs": "Node.js",
        "openai": "OpenAI",
        "chatgpt": "ChatGPT",
        "wifi": "Wi-Fi",
        "ebay": "eBay",
        "paypal": "PayPal",
        "wordpress": "WordPress",
    ]

    // MARK: - Title Case Exceptions

    static let titleCaseExceptions: Set<String> = [
        "a", "an", "the", "and", "but", "or", "nor", "for",
        "yet", "so", "at", "by", "in", "of", "on", "to",
        "up", "as", "if", "is", "it", "vs",
    ]

    // MARK: - "I" Contraction Pattern

    static let standaloneIPattern = #"(?<=\s|^|\n)(i)(?=\s|'|$|[.,!?;:\-\u2014])"#
    static let contractionIPattern = #"(?<=\s|^|\n)(i')(m|d|ll|ve)(?=\s|$|[.,!?;:])"#
}

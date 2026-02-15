import os

extension Logger {
    private static let subsystem = "com.thinkur"

    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let transcription = Logger(subsystem: subsystem, category: "transcription")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    static let textInsertion = Logger(subsystem: subsystem, category: "textInsertion")
    static let permissions = Logger(subsystem: subsystem, category: "permissions")
    static let app = Logger(subsystem: subsystem, category: "app")
}

import Foundation
import SwiftData

@Model
final class Shortcut {
    @Attribute(.unique) var trigger: String
    var expansion: String
    var createdAt: Date

    init(trigger: String, expansion: String, createdAt: Date = .now) {
        self.trigger = trigger
        self.expansion = expansion
        self.createdAt = createdAt
    }
}

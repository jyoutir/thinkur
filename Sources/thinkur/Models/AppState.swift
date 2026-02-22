import Foundation

enum AppState: Equatable {
    case idle
    case loading
    case listening
    case processing
    case error(String)
}

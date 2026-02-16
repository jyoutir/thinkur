import SwiftUI
import AppKit

struct AppIconView: View {
    let bundleID: String
    let appName: String
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let icon = Self.icon(for: bundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback: colored circle with first letter
                Text(appName.prefix(1).uppercased())
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color.accentColor.gradient))
            }
        }
        .frame(width: size, height: size)
    }

    private static func icon(for bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
    }
}

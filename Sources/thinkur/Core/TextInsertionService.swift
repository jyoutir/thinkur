import Cocoa
import os

final class TextInsertionService: TextInserting {
    func insertText(_ text: String) {
        let pasteboard = NSPasteboard.general

        // 1. Save current clipboard contents (all types)
        let savedItems = savePasteboard(pasteboard)

        // 2. Set transcribed text on clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Mark as transient so clipboard managers (like Paste, Maccy) ignore it
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))

        Logger.textInsertion.info("Clipboard set with transcribed text (\(text.count, privacy: .public) chars)")

        // 3. Simulate Cmd+V paste after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.pasteDelay) { [weak self] in
            self?.simulatePaste()

            // 4. Restore original clipboard after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.clipboardRestoreDelay) {
                self?.restorePasteboard(pasteboard, items: savedItems)
                Logger.textInsertion.info("Clipboard restored")
            }
        }
    }

    private func simulatePaste() {
        let src = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: Constants.vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: src, virtualKey: Constants.vKeyCode, keyDown: false) else {
            Logger.textInsertion.error("Failed to create paste CGEvents")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)

        Logger.textInsertion.info("Simulated Cmd+V paste")
    }

    private func savePasteboard(_ pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.compactMap { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict.isEmpty ? nil : dict
        }
    }

    private func restorePasteboard(
        _ pasteboard: NSPasteboard,
        items: [[NSPasteboard.PasteboardType: Data]]
    ) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }

        for itemDict in items {
            let item = NSPasteboardItem()
            for (type, data) in itemDict {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }
    }
}

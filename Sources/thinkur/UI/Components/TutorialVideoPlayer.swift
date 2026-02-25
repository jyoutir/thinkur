import SwiftUI
import AVFoundation

struct TutorialVideoPlayer: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true

        let playerItem = AVPlayerItem(url: url)
        let player = AVQueuePlayer(playerItem: playerItem)
        player.isMuted = true

        let looper = AVPlayerLooper(player: player, templateItem: playerItem)
        context.coordinator.player = player
        context.coordinator.looper = looper

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.cornerRadius = CornerRadius.card
        playerLayer.masksToBounds = true
        containerView.layer?.addSublayer(playerLayer)
        context.coordinator.playerLayer = playerLayer

        player.play()

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Resize player layer to match container
        DispatchQueue.main.async {
            context.coordinator.playerLayer?.frame = nsView.bounds
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.player = nil
        coordinator.looper = nil
    }

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
        var playerLayer: AVPlayerLayer?
    }
}

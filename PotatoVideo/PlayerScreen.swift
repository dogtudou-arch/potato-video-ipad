import AVFoundation
import Combine
import SwiftUI
import UIKit

private struct VideoSurface: UIViewRepresentable {
    let player: AVPlayer?

    final class Surface: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> Surface {
        let view = Surface()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: Surface, context: Context) {
        view.playerLayer.player = player
    }
}

struct PlayerScreen: View {
    let video: Video
    let episode: Episode

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var controlsVisible = true
    @State private var playing = true
    @State private var currentTime = 0.0
    @State private var duration = 0.0
    @State private var seeking = false
    @State private var seekHint: String?
    @State private var waitingAfterSeek = false
    @State private var gestureKind: GestureKind = .none
    @State private var gestureLevel = 0.0
    @State private var startLevel = 0.0
    @State private var hideTask: Task<Void, Never>?
    @State private var hintTask: Task<Void, Never>?
    @State private var lastManagementPoll = Date.distantPast

    private enum GestureKind: Equatable { case none, horizontal, brightness, volume }
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                VideoSurface(player: player)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: toggleControls)
                    .simultaneousGesture(drag(in: geometry.size))

                if controlsVisible {
                    VStack(spacing: 0) {
                        topCurtain
                        Spacer(minLength: 0)
                        bottomCurtain
                    }
                }

                if let seekHint {
                    Text(seekHint)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(.black.opacity(0.55), in: Capsule())
                        .allowsHitTesting(false)
                } else if waitingAfterSeek && isBuffering {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.25)
                        .padding(24)
                        .background(.black.opacity(0.45), in: Circle())
                        .allowsHitTesting(false)
                }

                if gestureKind == .brightness || gestureKind == .volume {
                    HStack {
                        if gestureKind == .volume { Spacer() }
                        levelHUD
                        if gestureKind == .brightness { Spacer() }
                    }
                    .padding(.horizontal, 28)
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .statusBarHidden()
        .task { await start() }
        .onDisappear(perform: stop)
        .onReceive(ticker) { _ in tick() }
    }

    private var isBuffering: Bool {
        player?.timeControlStatus == .waitingToPlayAtSpecifiedRate
    }

    private var topCurtain: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 36, height: 44)
            }
            Text(video.title + " · " + episode.name)
                .font(.system(size: 17, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 64)
        .background(LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))
    }

    private var bottomCurtain: some View {
        VStack(spacing: 4) {
            Slider(value: Binding(
                get: { duration > 0 ? currentTime / duration : 0 },
                set: { value in
                    currentTime = value * duration
                    seeking = true
                }
            ), in: 0...1, onEditingChanged: { editing in
                if !editing, let player {
                    player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
                    seeking = false
                    scheduleHide()
                }
            })
            .tint(.white)

            HStack(spacing: 16) {
                Button {
                    guard let player else { return }
                    if playing { player.pause() } else { player.play() }
                    playing.toggle()
                    scheduleHide()
                } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .frame(width: 30, height: 32)
                }
                Text(time(currentTime) + " / " + time(duration))
                    .font(.system(size: 13, design: .monospaced))
                Spacer()
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
    }

    private var levelHUD: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Capsule().fill(.white.opacity(0.3))
                    Capsule().fill(.white)
                        .frame(height: geometry.size.height * gestureLevel)
                }
            }
            .frame(width: 7, height: 96)
            Image(systemName: gestureKind == .brightness ? "sun.max.fill" : "speaker.wave.2.fill")
                .font(.system(size: 20))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
    }

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if gestureKind == .none {
                    if abs(dx) > abs(dy) {
                        gestureKind = .horizontal
                    } else {
                        gestureKind = value.startLocation.x < size.width / 2 ? .brightness : .volume
                        startLevel = gestureKind == .brightness
                            ? Double(UIScreen.main.brightness) : Double(player?.volume ?? 1)
                    }
                }
                if gestureKind == .brightness || gestureKind == .volume {
                    let next = min(1, max(0, startLevel - Double(dy / max(1, size.height))))
                    gestureLevel = next
                    if gestureKind == .brightness {
                        UIScreen.main.brightness = CGFloat(next)
                    } else {
                        player?.volume = Float(next)
                    }
                }
            }
            .onEnded { value in
                if gestureKind == .horizontal, abs(value.translation.width) >= 40 {
                    seekBy(value.translation.width > 0 ? 15 : -15)
                }
                if gestureKind == .brightness || gestureKind == .volume {
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        gestureKind = .none
                    }
                } else {
                    gestureKind = .none
                }
            }
    }

    private func seekBy(_ seconds: Double) {
        guard let player else { return }
        let limit = duration > 0 ? duration : Double.greatestFiniteMagnitude
        let target = min(limit, max(0, player.currentTime().seconds + seconds))
        guard target.isFinite else { return }
        waitingAfterSeek = true
        seekHint = seconds > 0 ? "+15s" : "−15s"
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        currentTime = target
        hintTask?.cancel()
        hintTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if !Task.isCancelled { seekHint = nil }
        }
    }

    private func toggleControls() {
        controlsVisible.toggle()
        if controlsVisible { scheduleHide() } else { hideTask?.cancel() }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled { controlsVisible = false }
        }
    }

    private func start() async {
        guard UsageWindow.isActive() else { dismiss(); return }
        guard await DeviceManagement.shared.canUse() else { dismiss(); return }
        guard !Task.isCancelled else { return }
        UserDefaults.standard.set(video.title + " · " + episode.name, forKey: "management_current_video")
        lastManagementPoll = Date()
        Task { _ = await DeviceManagement.shared.canUse(force: true) }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        let item = AVPlayerItem(url: episode.url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        player.play()
        playing = true
        controlsVisible = true
        scheduleHide()
        requestOrientation(.landscape)
    }

    private func stop() {
        UserDefaults.standard.removeObject(forKey: "management_current_video")
        Task { _ = await DeviceManagement.shared.canUse(force: true) }
        hideTask?.cancel()
        hintTask?.cancel()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        requestOrientation(.portrait)
    }

    private func tick() {
        if Date().timeIntervalSince(lastManagementPoll) >= 600 {
            lastManagementPoll = Date()
            Task {
                if !(await DeviceManagement.shared.canUse(force: true)) {
                    stop()
                    dismiss()
                }
            }
        }
        guard UsageWindow.isActive() else {
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            dismiss()
            return
        }
        guard let player else { return }
        if !seeking {
            let seconds = player.currentTime().seconds
            if seconds.isFinite { currentTime = seconds }
        }
        let length = player.currentItem?.duration.seconds ?? 0
        if length.isFinite && length > 0 { duration = length }
        if waitingAfterSeek && player.timeControlStatus == .playing {
            waitingAfterSeek = false
        }
        let pixels = Int(min(player.currentItem?.presentationSize.width ?? 0,
                             player.currentItem?.presentationSize.height ?? 0))
        if pixels > 0 {
            UserDefaults.standard.set("\(pixels)P", forKey: "quality_" + video.id)
        }
    }

    private func requestOrientation(_ orientation: UIInterfaceOrientationMask) {
        guard UIDevice.current.userInterfaceIdiom != .pad else { return }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
    }

    private func time(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let value = Int(seconds)
        if value >= 3600 {
            return String(format: "%02d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
        }
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

import SwiftUI

struct RadarEmptyStateView: View {
    let isScanning: Bool
    var idleTitle = "Ready to Scan"
    var scanningTitle = "Scanning Network"
    var idleSystemImage = "network"
    var scanningSystemImage = "network"
    var idleMessage: String? = nil
    var scanningMessage: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            NetworkActivityArtwork(isScanning: isScanning, symbol: isScanning ? scanningSystemImage : idleSystemImage)
                .frame(width: 280, height: 144)

            VStack(spacing: 6) {
                Text(isScanning ? scanningTitle : idleTitle)
                    .font(.title2.weight(.semibold))
                Text(isScanning ? (scanningMessage ?? "Discovering local devices and services") : (idleMessage ?? "Local network discovery"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 360)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NetworkActivityArtwork: View {
    let isScanning: Bool
    let symbol: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.colorSchemeContrast) private var contrast

    private var animates: Bool {
        isScanning && !reduceMotion && scenePhase == .active && activeState != .inactive
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animates)) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let points = [CGPoint(x: 28, y: 24), CGPoint(x: 24, y: 114),
                              CGPoint(x: 252, y: 24), CGPoint(x: 256, y: 114)]
                let time = animates ? timeline.date.timeIntervalSinceReferenceDate : 0
                for (index, point) in points.enumerated() {
                    var route = Path()
                    route.move(to: point)
                    route.addLine(to: CGPoint(x: center.x, y: point.y))
                    route.addLine(to: center)
                    context.stroke(route, with: .color(.secondary.opacity(contrast == .increased ? 0.65 : 0.22)),
                                   style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                    if animates {
                        let phase = (time * 0.55 + Double(index) * 0.23).truncatingRemainder(dividingBy: 1)
                        context.stroke(route.trimmedPath(from: max(0, phase - 0.13), to: phase),
                                       with: .color(.accentColor.opacity(0.8)),
                                       style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                    if let node = context.resolveSymbol(id: index) { context.draw(node, at: point) }
                }
                if let hub = context.resolveSymbol(id: 4) { context.draw(hub, at: center) }
            } symbols: {
                ForEach(0..<4) { index in
                    Image(systemName: index.isMultiple(of: 2) ? "desktopcomputer" : "wifi.router")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color(nsColor: .textBackgroundColor))
                        .tag(index)
                }
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 64, height: 64)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentColor.opacity(0.25)))
                    .tag(4)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

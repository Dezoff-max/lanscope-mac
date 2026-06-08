import SwiftUI

struct RadarEmptyStateView: View {
    let isScanning: Bool
    let isMockMode: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            SubnetSweepBackdrop(isScanning: isScanning)
                .opacity(colorScheme == .dark ? 0.95 : 0.82)

            VStack(spacing: 7) {
                Image(systemName: isScanning ? "network" : "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 32, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    Text(isScanning ? "Scanning Network" : "No Devices")
                        .font(.title3.weight(.semibold))
                        .contentTransition(.opacity)

                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(18)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var message: String {
        if isScanning {
            return isMockMode ? "Sample devices are arriving." : "Waiting for local hosts and open services."
        }
        return "Run a scan or enable sample data in Settings."
    }
}

struct ScanActivityDots: View {
    let isActive: Bool

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(isActive ? Color.cyan : Color.secondary.opacity(0.28))
                    .frame(width: 5, height: 5)
                    .scaleEffect(isActive && isAnimating ? 1.25 : 0.82)
                    .opacity(isActive ? 0.95 : 0.45)
                    .animation(
                        .easeInOut(duration: 0.62)
                        .repeatForever()
                        .delay(Double(index) * 0.13),
                        value: isAnimating
                    )
            }
        }
        .frame(width: 24)
        .onAppear {
            isAnimating = true
        }
    }
}

private struct SubnetSweepBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    let isScanning: Bool

    private let lanes: [Double] = [0.18, 0.31, 0.44, 0.57, 0.70, 0.83]
    private let devices: [SubnetDevice] = [
        .init(x: 0.12, y: 0.18, style: .workstation),
        .init(x: 0.26, y: 0.31, style: .server),
        .init(x: 0.38, y: 0.18, style: .phone),
        .init(x: 0.52, y: 0.44, style: .workstation),
        .init(x: 0.66, y: 0.31, style: .router),
        .init(x: 0.82, y: 0.18, style: .workstation),
        .init(x: 0.18, y: 0.57, style: .phone),
        .init(x: 0.34, y: 0.70, style: .workstation),
        .init(x: 0.48, y: 0.83, style: .server),
        .init(x: 0.63, y: 0.70, style: .workstation),
        .init(x: 0.78, y: 0.57, style: .phone),
        .init(x: 0.91, y: 0.83, style: .router)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            Canvas { context, size in
                drawSweep(in: &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .accessibilityHidden(true)
    }

    private func drawSweep(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let primary = Color(nsColor: .labelColor)
        let secondary = Color(nsColor: .secondaryLabelColor)
        let surface = Color(nsColor: .controlBackgroundColor)
        let cyan = Color.cyan
        let blue = Color.accentColor
        let isDark = colorScheme == .dark
        let insetX = max(48, size.width * 0.08)
        let top = max(36, size.height * 0.12)
        let bottom = max(36, size.height * 0.10)
        let map = CGRect(
            x: insetX,
            y: top,
            width: max(1, size.width - insetX * 2),
            height: max(1, size.height - top - bottom)
        )
        let sweepDuration = isScanning ? 3.4 : 6.8
        let sweepProgress = (time / sweepDuration).truncatingRemainder(dividingBy: 1)
        let sweepX = map.minX + map.width * sweepProgress

        drawColumns(in: &context, map: map, color: secondary.opacity(isDark ? 0.10 : 0.08))
        drawLanes(in: &context, map: map, color: primary.opacity(isDark ? 0.20 : 0.13))
        drawPackets(in: &context, map: map, time: time, color: cyan, secondaryColor: blue)
        drawSweepBeam(in: &context, map: map, x: sweepX, color: cyan, isDark: isDark)

        for (index, device) in devices.enumerated() {
            let point = point(for: device, in: map)
            let activation = max(0, 1 - abs(point.x - sweepX) / 95)
            let heartbeat = 0.5 + 0.5 * sin(time * 2.1 + Double(index) * 0.8)
            drawDevice(
                in: &context,
                at: point,
                style: device.style,
                activation: activation,
                heartbeat: heartbeat,
                surface: surface,
                primary: primary,
                accent: cyan,
                isDark: isDark
            )
        }
    }

    private func drawColumns(
        in context: inout GraphicsContext,
        map: CGRect,
        color: Color
    ) {
        for index in 0...8 {
            let x = map.minX + map.width * CGFloat(index) / 8
            var path = Path()
            path.move(to: CGPoint(x: x, y: map.minY))
            path.addLine(to: CGPoint(x: x, y: map.maxY))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: [5, 12]))
        }
    }

    private func drawLanes(in context: inout GraphicsContext, map: CGRect, color: Color) {
        for lane in lanes {
            let y = map.minY + map.height * CGFloat(lane)
            var path = Path()
            path.move(to: CGPoint(x: map.minX, y: y))
            path.addLine(to: CGPoint(x: map.maxX, y: y))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
    }

    private func drawPackets(in context: inout GraphicsContext, map: CGRect, time: TimeInterval, color: Color, secondaryColor: Color) {
        let speed = isScanning ? 0.38 : 0.22
        for (index, lane) in lanes.enumerated() {
            let y = map.minY + map.height * CGFloat(lane)
            let phase = (time * speed + Double(index) * 0.17).truncatingRemainder(dividingBy: 1)
            let x = map.minX + map.width * CGFloat(phase)
            let width = CGFloat(index.isMultiple(of: 2) ? 34 : 22)
            let packetRect = CGRect(x: x - width / 2, y: y - 2, width: width, height: 4)
            context.fill(roundedRect(packetRect, radius: 2), with: .color(color.opacity(0.72)))

            let replyPhase = (1 - phase + 0.36).truncatingRemainder(dividingBy: 1)
            let replyX = map.minX + map.width * CGFloat(replyPhase)
            let replyRect = CGRect(x: replyX - 10, y: y + 7, width: 20, height: 3)
            context.fill(roundedRect(replyRect, radius: 1.5), with: .color(secondaryColor.opacity(0.38)))
        }
    }

    private func drawSweepBeam(in context: inout GraphicsContext, map: CGRect, x: CGFloat, color: Color, isDark: Bool) {
        let beamWidth: CGFloat = 76
        let beamRect = CGRect(x: x - beamWidth / 2, y: map.minY - 14, width: beamWidth, height: map.height + 28)
        context.fill(
            Path(beamRect),
            with: .linearGradient(
                Gradient(colors: [.clear, color.opacity(isDark ? 0.16 : 0.10), .clear]),
                startPoint: CGPoint(x: beamRect.minX, y: beamRect.midY),
                endPoint: CGPoint(x: beamRect.maxX, y: beamRect.midY)
            )
        )

        var beam = Path()
        beam.move(to: CGPoint(x: x, y: map.minY - 12))
        beam.addLine(to: CGPoint(x: x, y: map.maxY + 12))
        context.stroke(
            beam,
            with: .color(color.opacity(isDark ? 0.46 : 0.36)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [8, 8])
        )
    }

    private func drawDevice(
        in context: inout GraphicsContext,
        at point: CGPoint,
        style: SubnetDevice.Style,
        activation: CGFloat,
        heartbeat: Double,
        surface: Color,
        primary: Color,
        accent: Color,
        isDark: Bool
    ) {
        let size = CGFloat(18 + activation * 4)
        let rect = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
        let fillOpacity = isDark ? 0.42 + activation * 0.24 : 0.76 + activation * 0.16
        let strokeOpacity = isDark ? 0.28 + activation * 0.56 : 0.20 + activation * 0.46
        let pulseOpacity = activation * CGFloat(0.18 + heartbeat * 0.08)

        if pulseOpacity > 0.01 {
            let pulseRect = rect.insetBy(dx: -7 - activation * 3, dy: -7 - activation * 3)
            context.stroke(
                roundedRect(pulseRect, radius: 8),
                with: .color(accent.opacity(pulseOpacity)),
                style: StrokeStyle(lineWidth: 1)
            )
        }

        context.fill(roundedRect(rect, radius: 5), with: .color(surface.opacity(fillOpacity)))
        context.stroke(
            roundedRect(rect, radius: 5),
            with: .color((activation > 0.18 ? accent : primary).opacity(strokeOpacity)),
            style: StrokeStyle(lineWidth: 1)
        )

        drawGlyph(in: &context, rect: rect.insetBy(dx: 4, dy: 4), style: style, color: primary.opacity(isDark ? 0.78 : 0.58), accent: accent.opacity(0.78))
    }

    private func drawGlyph(in context: inout GraphicsContext, rect: CGRect, style: SubnetDevice.Style, color: Color, accent: Color) {
        switch style {
        case .workstation:
            let screen = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.62)
            context.stroke(roundedRect(screen, radius: 1.5), with: .color(color), style: StrokeStyle(lineWidth: 1))
            var stand = Path()
            stand.move(to: CGPoint(x: rect.midX, y: screen.maxY))
            stand.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 1))
            stand.move(to: CGPoint(x: rect.minX + 2, y: rect.maxY - 1))
            stand.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY - 1))
            context.stroke(stand, with: .color(color), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        case .server:
            for index in 0..<3 {
                let unit = CGRect(x: rect.minX, y: rect.minY + CGFloat(index) * rect.height / 3, width: rect.width, height: rect.height / 3 - 1)
                context.stroke(roundedRect(unit, radius: 1), with: .color(color), style: StrokeStyle(lineWidth: 1))
                context.fill(Path(ellipseIn: CGRect(x: unit.maxX - 3, y: unit.midY - 1, width: 2, height: 2)), with: .color(accent))
            }
        case .phone:
            context.stroke(roundedRect(rect.insetBy(dx: 2, dy: 0), radius: 2), with: .color(color), style: StrokeStyle(lineWidth: 1))
            context.fill(roundedRect(CGRect(x: rect.midX - 2, y: rect.maxY - 1.5, width: 4, height: 1), radius: 0.5), with: .color(color))
        case .router:
            context.stroke(roundedRect(CGRect(x: rect.minX, y: rect.midY - 3, width: rect.width, height: 6), radius: 2), with: .color(color), style: StrokeStyle(lineWidth: 1))
            context.fill(Path(ellipseIn: CGRect(x: rect.minX + 2, y: rect.midY - 1, width: 2, height: 2)), with: .color(accent))
            context.fill(Path(ellipseIn: CGRect(x: rect.maxX - 4, y: rect.midY - 1, width: 2, height: 2)), with: .color(accent))
        }
    }

    private func point(for device: SubnetDevice, in map: CGRect) -> CGPoint {
        CGPoint(
            x: map.minX + map.width * CGFloat(device.x),
            y: map.minY + map.height * CGFloat(device.y)
        )
    }

    private func roundedRect(_ rect: CGRect, radius: CGFloat) -> Path {
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius))
        return path
    }
}

private struct SubnetDevice {
    enum Style {
        case workstation
        case server
        case phone
        case router
    }

    let x: Double
    let y: Double
    let style: Style
}

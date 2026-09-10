import SwiftUI

enum InterfaceMotion {
    static func transition(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.32, dampingFraction: 1)
    }
}

struct AppearingCell<ID: Hashable, Content: View>: View {
    let id: ID
    var delay: Double = 0
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        content()
            .frame(minHeight: 32)
            .opacity(reduceMotion || isVisible ? 1 : 0.45)
            .offset(y: reduceMotion || isVisible ? 0 : 3)
            .task(id: id) {
                // Animate presentation only; results stay available for selection and export.
                isVisible = false
                await Task.yield()
                guard !Task.isCancelled else { return }
                withAnimation(InterfaceMotion.transition(reduceMotion: reduceMotion)
                    .delay(reduceMotion ? 0 : min(delay, 0.24))) {
                    isVisible = true
                }
            }
    }
}

struct ChromeSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if reduceTransparency || contrast == .increased {
            Color(nsColor: .controlBackgroundColor)
        } else {
            Rectangle().fill(.bar)
        }
    }
}

struct ScanStatusBar: View {
    let message: String
    let isScanning: Bool
    let count: Int
    let noun: String
    var progress: Double? = nil

    private var failed: Bool { message.localizedCaseInsensitiveContains("failed") }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if isScanning {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: failed ? "exclamationmark.circle" : count > 0 ? "checkmark.circle" : "circle.dotted")
                        .foregroundStyle(failed ? Color.orange : Color.secondary)
                }
            }
            .frame(width: 16, height: 16)

            Text(message)
                .foregroundStyle(failed ? .primary : .secondary)
                .lineLimit(2)
                .help(message)

            Spacer(minLength: 12)

            if isScanning, let progress {
                ProgressView(value: progress)
                    .frame(width: 100)
                    .accessibilityLabel("Scan progress")
            }

            Text("\(count) \(noun)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .fixedSize()
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background { ChromeSurface() }
    }
}

struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

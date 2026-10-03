import Charts
import SwiftUI

struct DeviceMonitorView: View {
    @EnvironmentObject private var monitor: DeviceMonitorStore
    let device: Device
    var interfaceName: String? = nil

    private var snapshot: DeviceMonitorSnapshot { monitor.snapshot(for: device) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Мониторинг", systemImage: "waveform.path.ecg")
                    .font(.headline)
                Spacer()
                if snapshot.isProbing {
                    ProgressView().controlSize(.mini).help("Ожидание ответа на ping")
                }
            }

            Label(statusText, systemImage: statusSymbol)
                .font(.caption)
                .foregroundStyle(statusColor)
                .fixedSize(horizontal: false, vertical: true)

            if snapshot.samples.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "chart.xyaxis.line").font(.title2)
                    Text("Задержка и потери за 5 минут")
                    Text("Запустите мониторинг или проверьте устройство один раз.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 105)
            } else {
                latencyChart
                HStack(alignment: .top, spacing: 12) {
                    metric("Средняя", latency: snapshot.averageLatencyMS)
                    metric("Максимум", latency: snapshot.maximumLatencyMS)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Потери").font(.caption).foregroundStyle(.secondary)
                        Text(snapshot.lossPercent.map { String(format: "%.0f %%", $0) } ?? "—")
                            .monospacedDigit()
                            .foregroundStyle((snapshot.lossPercent ?? 0) > 0 ? Color.orange : .primary)
                    }
                }
                if let last = snapshot.lastSample {
                    Text("Последняя проверка: \(last.timestamp.formatted(date: .omitted, time: .standard)) · \(snapshot.samples.count) проверок")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 8) {
                Button {
                    if snapshot.isMonitoring {
                        monitor.stop(device: device)
                    } else {
                        monitor.start(device: device, interfaceName: interfaceName)
                    }
                } label: {
                    Label(snapshot.isMonitoring ? "Остановить" : "Начать", systemImage: snapshot.isMonitoring ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    Task { await monitor.probeOnce(device: device, interfaceName: interfaceName) }
                } label: {
                    Label("Проверить", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(snapshot.isProbing || monitor.pauseReason != nil)
            }

            DisclosureGroup("Параметры мониторинга") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Интервал", selection: $monitor.interval) {
                        Text("2 с").tag(TimeInterval(2))
                        Text("5 с").tag(TimeInterval(5))
                        Text("10 с").tag(TimeInterval(10))
                        Text("30 с").tag(TimeInterval(30))
                    }
                    Picker("Сообщать после", selection: $monitor.failureThreshold) {
                        Text("2 пропусков").tag(2)
                        Text("3 пропусков").tag(3)
                        Text("5 пропусков").tag(5)
                    }
                    .help("Сколько проверок подряд должны остаться без ответа перед уведомлением")
                    if monitor.notificationsEnabled {
                        Label("Уведомления включены", systemImage: "bell.badge")
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Включить уведомления macOS…", systemImage: "bell") {
                            Task { await monitor.requestNotifications() }
                        }
                    }
                    if let message = monitor.notificationMessage {
                        Text(message).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Настройки общие для всех устройств. История хранится только до закрытия приложения.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Очистить график") { monitor.clearHistory(for: device) }
                        .disabled(snapshot.samples.isEmpty)
                }
                .font(.caption)
                .padding(.top, 8)
            }
            .font(.caption)

            Text("Отсутствие ответа на ping может означать блокировку ICMP. Это не доказывает, что устройство выключено.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var latencyChart: some View {
        Chart {
            ForEach(latencyPoints) { point in
                LineMark(
                    x: .value("Время", point.timestamp),
                    y: .value("Задержка, мс", point.latency),
                    series: .value("Последовательность", point.segment)
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.linear)
                PointMark(x: .value("Время", point.timestamp), y: .value("Задержка, мс", point.latency))
                    .symbolSize(10)
                    .foregroundStyle(Color.accentColor)
            }
            ForEach(snapshot.samples.filter { !$0.reachable }) { sample in
                PointMark(x: .value("Время", sample.timestamp), y: .value("Нет ответа", 0))
                    .symbol(.cross)
                    .symbolSize(25)
                    .foregroundStyle(.orange)
            }
        }
        .chartXScale(domain: chartRange)
        .chartYScale(domain: 0...max(5, (snapshot.maximumLatencyMS ?? 1) * 1.15))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute().second())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
        }
        .chartYAxisLabel("мс", alignment: .leading)
        .chartLegend(.hidden)
        .frame(height: 125)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("График задержки. Потери \(Int(snapshot.lossPercent ?? 0)) процентов. \(snapshot.samples.count) проверок.")
    }

    private struct LatencyPoint: Identifiable {
        let id: UUID
        let timestamp: Date
        let latency: Double
        let segment: Int
    }

    /// Leave a visible gap when a ping is lost rather than implying continuous latency data.
    private var latencyPoints: [LatencyPoint] {
        var segment = 0
        return snapshot.samples.compactMap { sample in
            guard sample.reachable, let latency = sample.latencyMS else {
                segment += 1
                return nil
            }
            return LatencyPoint(id: sample.id, timestamp: sample.timestamp, latency: latency, segment: segment)
        }
    }

    private var chartRange: ClosedRange<Date> {
        let end = snapshot.lastSample?.timestamp ?? Date()
        let start = min(snapshot.samples.first?.timestamp ?? end, end.addingTimeInterval(-30))
        return start...end.addingTimeInterval(1)
    }

    private var statusText: String {
        if snapshot.isMonitoring, let reason = monitor.pauseReason { return "Пауза: \(reason.lowercased())" }
        if snapshot.lastSample?.reachable == true { return "Отвечает на ping" }
        if snapshot.confirmedReachable == false { return "Нет ответа на ping" }
        if snapshot.lastSample != nil { return "Нет ответа · \(snapshot.consecutiveFailures)/\(monitor.failureThreshold)" }
        return snapshot.isMonitoring ? "Проверяем доступность…" : "Мониторинг выключен"
    }

    private var statusSymbol: String {
        if snapshot.isMonitoring, monitor.pauseReason != nil { return "pause.circle" }
        if snapshot.lastSample?.reachable == true { return "checkmark.circle.fill" }
        return snapshot.lastSample == nil ? "circle.dotted" : "exclamationmark.circle"
    }

    private var statusColor: Color {
        if snapshot.isMonitoring, monitor.pauseReason != nil { return .secondary }
        if snapshot.lastSample?.reachable == true { return .green }
        return snapshot.lastSample == nil ? .secondary : .orange
    }

    private func metric(_ title: String, latency: Double?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(latency.map { String(format: "%.1f мс", $0) } ?? "—").monospacedDigit()
        }
    }
}

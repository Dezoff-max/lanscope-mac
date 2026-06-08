import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var config: ScannerConfig

    var body: some View {
        Form {
            Section("Scanner") {
                TextField("Default Range", text: $config.ipRange)
                    .font(.system(.body, design: .monospaced))

                TextField("Ports", text: portsText)
                    .font(.system(.body, design: .monospaced))

                Stepper(value: $config.timeout, in: 0.2...10.0, step: 0.1) {
                    Text("Timeout: \(config.timeout, specifier: "%.1f") s")
                }

                Stepper(value: $config.concurrencyLimit, in: 1...512, step: 1) {
                    Text("Parallel limit: \(config.concurrencyLimit)")
                }
            }

            Section("Lookup") {
                Toggle("Vendor lookup", isOn: $config.vendorLookupEnabled)
                Toggle("Sample data", isOn: $config.mockMode)
                    .help("Shows sample devices without scanning the network.")
                HStack {
                    Text("Vendor records")
                    Spacer()
                    Text("\(appState.vendorDatabaseCount)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Button {
                    appState.updateOUIDatabase()
                } label: {
                    if appState.isUpdatingOUIDatabase {
                        Label("Updating OUI", systemImage: "arrow.triangle.2.circlepath")
                    } else {
                        Label("Update OUI from IEEE", systemImage: "arrow.down.circle")
                    }
                }
                .disabled(appState.isUpdatingOUIDatabase)
            }

            Section("Appearance") {
                Picker("Theme", selection: $config.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Local Network") {
                HStack {
                    Text(config.ipRange)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        appState.useDetectedRange()
                    } label: {
                        Label("Detect Range", systemImage: "location")
                    }
                    .help("Detect the local IPv4 subnet and fill the scan range.")
                }
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(minWidth: 460, idealWidth: 540, maxWidth: 620, maxHeight: .infinity, alignment: .topLeading)
        .animation(.snappy(duration: 0.2), value: appState.vendorDatabaseCount)
    }

    private var portsText: Binding<String> {
        Binding(
            get: {
                config.ports.map(String.init).joined(separator: ", ")
            },
            set: { value in
                let parsed = PortListParser.parse(value)
                if !parsed.isEmpty {
                    config.ports = parsed
                }
            }
        )
    }
}

import SwiftUI

struct DeviceMetadataEditor: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let device: Device
    @State private var name: String
    @State private var kind: DeviceKind
    @State private var notes: String
    @State private var tags: String

    init(device: Device) {
        self.device = device
        _name = State(initialValue: device.customName)
        _kind = State(initialValue: device.kind)
        _notes = State(initialValue: device.notes)
        _tags = State(initialValue: device.tags.joined(separator: ", "))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Устройство").font(.title2.bold())
                    Text(device.ipAddress).monospaced().foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: kind.systemImage).font(.largeTitle).foregroundStyle(Color.accentColor)
            }.padding(22)
            Form {
                TextField("Название", text: $name, prompt: Text("Например, Мост1 или сервер офиса"))
                Picker("Тип", selection: $kind) {
                    ForEach(DeviceKind.allCases) { kind in
                        Label(kind.title, systemImage: kind.systemImage).tag(kind)
                    }
                }
                TextField("Метки", text: $tags, prompt: Text("Через запятую: склад, важное"))
                LabeledContent("Заметка") {
                    TextEditor(text: $notes).frame(height: 105)
                        .font(.body)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.2)))
                }
                Text("Название, тип и заметки сохраняются для этого устройства в выбранной сети.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Сохранить") {
                    appState.updateDeviceMetadata(device, name: name, kind: kind, notes: notes,
                                                  tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
                    dismiss()
                }.keyboardShortcut(.defaultAction)
            }.padding(18)
        }.frame(width: 480)
    }
}

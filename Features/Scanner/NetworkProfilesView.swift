import SwiftUI

struct NetworkProfilesView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var pendingDelete: NetworkProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Объекты и сети").font(.title2.bold())
                    Text("Свои диапазоны и настройки для дома, офиса и склада.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Готово") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if appState.profiles.isEmpty {
                ContentUnavailableView("Пока нет профилей", systemImage: "network",
                                       description: Text("Сохраните текущие настройки под названием объекта."))
                    .frame(height: 150)
            } else {
                List {
                    ForEach(appState.profiles) { profile in
                        HStack(spacing: 10) {
                            Image(systemName: appState.config.profileID == profile.id ? "checkmark.circle.fill" : "network")
                                .foregroundStyle(appState.config.profileID == profile.id ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name).fontWeight(.medium)
                                Text(profile.config.ipRange).font(.caption).monospaced().foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Выбрать") { appState.selectProfile(profile.id); dismiss() }
                                .disabled(appState.config.profileID == profile.id)
                            Button(role: .destructive) { pendingDelete = profile } label: { Image(systemName: "trash") }
                                .disabled(appState.profiles.count <= 1)
                                .help(appState.profiles.count <= 1 ? "Нужен хотя бы один профиль сети" : "Удалить профиль")
                        }.padding(.vertical, 4)
                    }
                }.frame(minHeight: 160, maxHeight: 280)
            }
            Divider()
            Text("Сохранить текущие настройки").font(.headline)
            Text("\(appState.config.ipRange) · \(appState.config.ports.count) портов · \(appState.config.interfaceName ?? "автоматический интерфейс")")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                TextField("Название объекта", text: $name).textFieldStyle(.roundedBorder)
                    .onSubmit(save)
                Button("Сохранить", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22).frame(width: 550)
        .confirmationDialog("Удалить профиль?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                if let profile = pendingDelete { appState.deleteProfile(profile.id) }
                pendingDelete = nil
            }
            Button("Отмена", role: .cancel) { pendingDelete = nil }
        } message: { Text("Можно удалить только профиль без сохранённой истории, избранного и заметок устройств. Если в профиле «\(pendingDelete?.name ?? "")» есть эти данные, он останется без изменений.") }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appState.saveProfile(name: trimmed)
        name = ""
    }
}

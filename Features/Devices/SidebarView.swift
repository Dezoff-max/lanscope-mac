import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarSection?

    var body: some View {
        List(selection: $selection) {
            Section("LanScope Mac") {
                ForEach(SidebarSection.allCases) { section in
                    Label(section.title, systemImage: section.symbolName)
                    .symbolRenderingMode(.hierarchical)
                    .padding(.vertical, 3)
                    .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("LanScope Mac")
        .frame(minWidth: 164)
    }
}

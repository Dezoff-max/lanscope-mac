import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarSection?

    private var idealWidth: CGFloat {
        let longestTitle = SidebarSection.allCases.map(\.title.count).max() ?? 0
        return max(122, CGFloat(longestTitle) * 7.2 + 58)
    }

    var body: some View {
        List(selection: $selection) {
            Section("LanScope Mac") {
                ForEach(SidebarSection.allCases) { section in
                    HStack(spacing: 8) {
                        Text(section.emojiIcon)
                            .font(.system(size: 15))
                            .frame(width: 18)
                        Text(section.title)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 1)
                    .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("LanScope Mac")
        .frame(width: idealWidth)
    }
}

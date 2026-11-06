import SwiftUI
import AppKit

/// Name your own lists and stages. Renaming updates every contact that uses the old name.
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var newList = ""
    @State private var newStage = ""

    var body: some View {
        Form {
            Section("Lists: how you group your network") {
                ForEach(store.config.lists) { item in
                    ItemRow(item: item, canDelete: true,
                            rename: { new in renameList(item.name, new) },
                            recolor: { color in store.updateConfig { $0.lists[index($0.lists, item)].color = color } },
                            move: { d in store.updateConfig { move(&$0.lists, item, d) } },
                            delete: { deleteList(item.name) })
                }
                HStack {
                    TextField("New list", text: $newList)
                    Button("Add") {
                        let n = newList.trimmingCharacters(in: .whitespaces)
                        guard !n.isEmpty, !store.config.lists.contains(where: { $0.name == n }) else { return }
                        store.updateConfig { $0.lists.append(NamedColor(name: n, color: "blue")) }
                        newList = ""
                    }
                }
                Text("Deleting a list moves its people to Unclassified.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Stages: where each relationship stands") {
                ForEach(store.config.stages) { item in
                    ItemRow(item: item, canDelete: store.config.stages.count > 1 && item.name != store.config.defaultStage,
                            rename: { new in renameStage(item.name, new) },
                            recolor: { color in store.updateConfig { $0.stages[index($0.stages, item)].color = color } },
                            move: { d in store.updateConfig { move(&$0.stages, item, d) } },
                            delete: { deleteStage(item.name) })
                }
                HStack {
                    TextField("New stage", text: $newStage)
                    Button("Add") {
                        let n = newStage.trimmingCharacters(in: .whitespaces)
                        guard !n.isEmpty, !store.config.stages.contains(where: { $0.name == n }) else { return }
                        store.updateConfig { $0.stages.append(NamedColor(name: n, color: "gray")) }
                        newStage = ""
                    }
                }
                Picker("New contacts start on", selection: Binding(
                    get: { store.config.defaultStage },
                    set: { v in store.updateConfig { $0.defaultStage = v } })) {
                    ForEach(store.config.stages) { Text($0.name).tag($0.name) }
                }
                Text("The last stage counts as dormant: it is left out of Going cold.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Data file") {
                Text(store.url.path).font(.caption).textSelection(.enabled)
                Button("Choose another file…") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.json]
                    if panel.runModal() == .OK, let u = panel.url { store.useFile(u) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 640)
    }

    private func index(_ a: [NamedColor], _ x: NamedColor) -> Int { a.firstIndex { $0.name == x.name } ?? 0 }

    private func move(_ a: inout [NamedColor], _ x: NamedColor, _ by: Int) {
        guard let i = a.firstIndex(where: { $0.name == x.name }) else { return }
        let j = i + by
        if a.indices.contains(j) { a.swapAt(i, j) }
    }

    private func renameList(_ old: String, _ new: String) {
        guard !new.isEmpty, new != old, !store.config.lists.contains(where: { $0.name == new }) else { return }
        store.updateConfig(rewrite: { c in if c.net?.list == old { c.net?.list = new } }) { conf in
            if let i = conf.lists.firstIndex(where: { $0.name == old }) { conf.lists[i].name = new }
        }
    }

    private func deleteList(_ name: String) {
        store.updateConfig(rewrite: { c in if c.net?.list == name { c.net = nil } }) { $0.lists.removeAll { $0.name == name } }
    }

    private func renameStage(_ old: String, _ new: String) {
        guard !new.isEmpty, new != old, !store.config.stages.contains(where: { $0.name == new }) else { return }
        store.updateConfig(rewrite: { c in if c.stage == old { c.stage = new } }) { conf in
            if let i = conf.stages.firstIndex(where: { $0.name == old }) { conf.stages[i].name = new }
            if conf.defaultStage == old { conf.defaultStage = new }
        }
    }

    private func deleteStage(_ name: String) {
        let fallback = store.config.defaultStage
        store.updateConfig(rewrite: { c in if c.stage == name { c.stage = fallback } }) { $0.stages.removeAll { $0.name == name } }
    }
}

private struct ItemRow: View {
    let item: NamedColor
    let canDelete: Bool
    let rename: (String) -> Void
    let recolor: (String) -> Void
    let move: (Int) -> Void
    let delete: () -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.named(item.color)).frame(width: 12, height: 12)
            Menu("") {
                ForEach(Theme.colorNames, id: \.self) { c in Button(c.capitalized) { recolor(c) } }
            }
            .menuStyle(.borderlessButton).fixedSize().help("Change color")
            TextField("", text: $text).labelsHidden().focused($focused)
                .onSubmit { rename(text.trimmingCharacters(in: .whitespaces)) }
            Button { move(-1) } label: { Image(systemName: "chevron.up") }.buttonStyle(.borderless)
            Button { move(1) } label: { Image(systemName: "chevron.down") }.buttonStyle(.borderless)
            Button(role: .destructive) { delete() } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless).disabled(!canDelete)
        }
        .onAppear { text = item.name }
        .onChange(of: item.name) { _, v in text = v }
        .onChange(of: focused) { _, on in if !on { rename(text.trimmingCharacters(in: .whitespaces)) } }
    }
}

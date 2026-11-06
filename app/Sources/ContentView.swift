import SwiftUI

enum Place: Hashable {
    case today, notes, updates, cold, everyone, list(String), unclassified, stage(String)

    var title: String {
        switch self {
        case .today: return "Today"
        case .notes: return "Notes for Claude"
        case .updates: return "LinkedIn updates"
        case .cold: return "Going cold"
        case .everyone: return "Everyone"
        case .list(let l): return l
        case .unclassified: return "Unclassified"
        case .stage(let s): return s
        }
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case list = "List order", due = "Check-in date", last = "Longest since contact", name = "Name"
    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @AppStorage("place") private var placeKey = "today"
    @AppStorage("leadersOnly") private var leadersOnly = false
    @AppStorage("sort") private var sort = SortOrder.list.rawValue
    @State private var selection: String?
    @State private var search = ""
    @State private var showNew = false

    private var place: Place {
        switch placeKey {
        case "today": return .today
        case "notes": return .notes
        case "updates": return .updates
        case "cold": return .cold
        case "everyone": return .everyone
        case "unclassified": return .unclassified
        default:
            if placeKey.hasPrefix("stage:") { return .stage(String(placeKey.dropFirst(6))) }
            return placeKey.hasPrefix("list:") ? .list(String(placeKey.dropFirst(5))) : .today
        }
    }

    private func key(_ p: Place) -> String {
        switch p {
        case .today: return "today"
        case .notes: return "notes"
        case .updates: return "updates"
        case .cold: return "cold"
        case .everyone: return "everyone"
        case .unclassified: return "unclassified"
        case .list(let l): return "list:" + l
        case .stage(let s): return "stage:" + s
        }
    }

    private func members(_ p: Place) -> [Contact] {
        store.contacts.filter { c in
            if leadersOnly && !c.isLeader { return false }
            switch p {
            case .today: return [.overdue, .today, .week].contains(c.due)
            case .notes: return !c.openNotes.isEmpty
            case .updates: return !c.unseenChanges.isEmpty
            case .cold: return c.isCold
            case .everyone: return true
            case .list(let l): return c.listName == l
            case .unclassified: return c.net == nil
            case .stage(let s): return c.stage == s
            }
        }
    }

    private var visible: [Contact] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        var rows = members(place)
        if !q.isEmpty {
            rows = rows.filter { c in
                [c.name, c.company, c.role, c.email, c.tags.joined(separator: " "), c.notes]
                    .joined(separator: " ").lowercased().contains(q)
            }
        }
        let order = place == .today ? SortOrder.due : (SortOrder(rawValue: sort) ?? .list)
        switch order {
        case .list:
            func pos(_ c: Contact) -> Int { c.net.map { Vocab.lists.firstIndex(of: $0.list) ?? 98 } ?? 99 }
            return rows.sorted { (pos($0), $0.net?.rank ?? 9999, $0.name) < (pos($1), $1.net?.rank ?? 9999, $1.name) }
        case .due:
            return rows.sorted { ($0.nextFollowUp.ifEmpty("9999"), $0.name) < ($1.nextFollowUp.ifEmpty("9999"), $1.name) }
        case .last:
            return rows.sorted { ($0.lastContact.ifEmpty("0000"), $0.name) < ($1.lastContact.ifEmpty("0000"), $1.name) }
        case .name:
            return rows.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 230, ideal: 260)
        } content: {
            contactList.navigationSplitViewColumnWidth(min: 300, ideal: 360)
        } detail: {
            if let id = selection, store.contact(id) != nil {
                DetailView(id: id).id(id)
            } else {
                emptyDetail
            }
        }
                .sheet(isPresented: $showNew) {
            EditSheet(contact: nil) { new in
                if let id = store.add(new) { selection = id }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newContact)) { _ in showNew = true }
        .onReceive(NotificationCenter.default.publisher(for: .setStage)) { n in
            if let s = n.object as? String, let id = selection { store.update(id) { $0.stage = s } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openContact)) { n in
            if let id = n.object as? String { placeKey = "everyone"; leadersOnly = false; selection = id }
        }
        .overlay(alignment: .bottom) {
            if let e = store.loadError {
                Text(e).font(Theme.body(12)).padding(10).background(RoundedRectangle(cornerRadius: 8).fill(Theme.tint(.red))).padding()
            }
        }
    }

    // MARK: Sidebar

    private func row(_ p: Place, _ icon: String, color: Color = .accentColor) -> some View {
        let n = members(p).count
        return Label {
            HStack {
                Text(p.title).font(Theme.body(13, .medium)).lineLimit(1)
                Spacer()
                Text("\(n)").font(Theme.body(11)).monospacedDigit().foregroundStyle(Theme.muted)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(color)
        }
        .tag(key(p))
    }

    private var sidebar: some View {
        List(selection: Binding(get: { placeKey }, set: { placeKey = $0 ?? "today"; selection = nil })) {
            Section {
                row(.today, "sun.max", color: .orange)
                row(.notes, "text.bubble", color: .purple)
                row(.updates, "arrow.triangle.2.circlepath", color: .teal)
                row(.cold, "snowflake", color: .blue)
            }
            Section("Network") {
                row(.everyone, "person.3", color: .blue)
                ForEach(Vocab.lists, id: \.self) { l in
                    row(.list(l), "circle.fill", color: Theme.listColor(l))
                }
                row(.unclassified, "tray", color: Theme.muted)
            }
            Section("Stages") {
                ForEach(Vocab.stages, id: \.self) { s in
                    row(.stage(s), "circle.fill", color: Theme.stageColor(s))
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Network Compass").font(Theme.title(19))
                Text("Your network, one place").font(Theme.body(11)).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 4)
        }
        .safeAreaInset(edge: .bottom) {
            Toggle(isOn: $leadersOnly) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Leaders only").font(Theme.body(13, .medium))
                    Text("C-level, VP, GM, MD, Head of").font(Theme.body(10.5)).foregroundStyle(Theme.muted)
                }
            }
            .toggleStyle(.switch)
            .padding(12)
        }
    }

    // MARK: Contact list

    private var contactList: some View {
        let rows = visible
        return List(selection: $selection) {
            if rows.isEmpty {
                Text(place == .today ? "Nobody is due a check-in this week." : "Nobody here.")
                    .font(Theme.body(13)).foregroundStyle(Theme.muted).padding(.vertical, 20)
            }
            ForEach(rows) { c in
                ContactRow(contact: c).tag(c.id)
                    .contextMenu {
                        Section("List") {
                            ForEach(Vocab.lists, id: \.self) { l in
                                Button(l == c.listName ? "✓ \(l)" : l) { store.setList(c.id, l) }
                            }
                            Button(c.net == nil ? "✓ Unclassified" : "Unclassified") { store.setList(c.id, nil) }
                        }
                        Section("Stage") {
                            ForEach(Vocab.stages, id: \.self) { s in
                                Button { store.update(c.id) { $0.stage = s } } label: {
                                    Text(s == c.stage ? "✓ \(s)" : s)
                                }
                            }
                        }
                    }
            }
        }
        .listStyle(.inset)
        .searchable(text: $search, placement: .toolbar, prompt: "Name, company, tag")
        .navigationTitle(place.title)
        .navigationSubtitle("\(rows.count) \(rows.count == 1 ? "person" : "people")\(leadersOnly ? " · leaders only" : "")")
        .toolbar {
            if place != .today {
                Picker("Sort", selection: $sort) {
                    ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                .pickerStyle(.menu).frame(width: 190)
            }
            Button { showNew = true } label: { Label("New contact", systemImage: "plus") }
                .help("New contact (⌘N)")
        }
    }

    private var emptyDetail: some View {
        VStack(spacing: 8) {
            Text(store.contacts.isEmpty ? "No contacts yet" : "Pick someone from the list").font(Theme.title(18))
            Text(store.contacts.isEmpty ? "Run /setup-network and /mine-network in Claude Code, or add someone with ⌘N."
                                        : "Their history, opening lines and notes appear here.").font(Theme.body(13)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
    }
}

struct ContactRow: View {
    let contact: Contact
    var body: some View {
        let c = contact
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(c.net.map { Theme.listColor($0.list) } ?? Theme.line).frame(width: 8, height: 8).padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(c.name).font(Theme.body(13.5, .semibold)).lineLimit(1)
                    ScoreBadge(score: c.score)
                    Spacer(minLength: 4)
                    if !c.unseenChanges.isEmpty { Chip(text: "job change", color: .teal) }
                    else if !c.openNotes.isEmpty { Chip(text: "note for Claude", color: .purple) }
                    else { DuePill(contact: c) }
                }
                Text(c.subtitle.ifEmpty("No role or company")).font(Theme.body(12)).foregroundStyle(Theme.muted).lineLimit(1)
                HStack(spacing: 8) {
                    HStack(spacing: 4) { StageDot(stage: c.stage, size: 7); Text(c.stage).font(Theme.body(11)).foregroundStyle(Theme.muted) }
                    // Only touchpoints logged in this app count; nothing shows until there is one
                    if !c.lastContact.isEmpty {
                        Text("last touchpoint \(Day.relative(c.lastContact))").font(Theme.body(11)).foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

extension Notification.Name {
    static let newContact = Notification.Name("newContact")
    static let openContact = Notification.Name("openContact")
    static let setStage = Notification.Name("setStage")
}

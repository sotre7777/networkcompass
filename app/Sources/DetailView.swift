import SwiftUI

struct DetailView: View {
    @EnvironmentObject var store: Store
    let id: String

    @State private var editing = false
    @State private var confirmDelete = false
    // Log a touchpoint
    @State private var logDate = Date()
    @State private var logType = "Email"
    @State private var logStage = Vocab.defaultStage
    @State private var logAsk = ""
    @State private var logStatus = ""
    @State private var logSummary = ""
    @State private var remindOn = true
    @State private var remindDate = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
    // Note for Claude
    @State private var noteText = ""
    @State private var showCalendar = false

    private var c: Contact? { store.contact(id) }

    var body: some View {
        if let c {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header(c)
                    if !c.unseenChanges.isEmpty { jobChanges(c) }
                    statusRow(c)
                    contactInfo(c)
                    if !c.notes.isEmpty { notes(c) }
                    if let n = c.net { NetworkSection(net: n) }
                    notesForClaude(c)
                    logForm(c)
                    history(c)
                }
                .padding(.horizontal, 28).padding(.vertical, 24)
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.paper)
            .onAppear { logStage = c.stage }
            .sheet(isPresented: $editing) {
                EditSheet(contact: c) { edited in
                    store.update(id) { x in
                        x.name = edited.name; x.company = edited.company; x.role = edited.role
                        x.email = edited.email; x.phone = edited.phone; x.linkedin = edited.linkedin
                        x.stage = edited.stage; x.tags = edited.tags; x.notes = edited.notes
                        x.nextFollowUp = edited.nextFollowUp
                    }
                }
            }
            .confirmationDialog("Delete \(c.name)?", isPresented: $confirmDelete) {
                Button("Delete contact", role: .destructive) { store.delete(id) }
            } message: { Text("Their history and notes are removed too.") }
        }
    }

    // MARK: Sections

    private func header(_ c: Contact) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(c.name).font(Theme.title(26)).textSelection(.enabled)
                Text([c.role, c.company].filter { !$0.isEmpty }.joined(separator: " at ").ifEmpty("No role or company yet"))
                    .font(Theme.body(14)).foregroundStyle(Theme.muted).textSelection(.enabled)
                HStack(spacing: 6) {
                    Menu {
                        ForEach(Vocab.lists, id: \.self) { l in Button(l) { store.setList(id, l) } }
                        Divider()
                        Button("Unclassified") { store.setList(id, nil) }
                    } label: {
                        Chip(text: c.net?.list ?? "Unclassified", color: c.net.map { Theme.listColor($0.list) } ?? .secondary)
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                    if let cat = c.net?.category, !cat.isEmpty { Chip(text: cat) }
                    if c.isLeader { Chip(text: "Leader", color: .teal) }
                }.padding(.top, 4)
            }
            Spacer()
            HStack {
                Button("Edit") { editing = true }.keyboardShortcut("e", modifiers: .command)
                Button(role: .destructive) { confirmDelete = true } label: { Text("Delete") }
            }
            .font(Theme.body(13))
        }
    }

    private func jobChanges(_ c: Contact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "LinkedIn update")
                Spacer()
                Button("Mark as seen") {
                    store.update(id) { x in x.changes = x.changes.map { var y = $0; y.seen = true; return y } }
                }
            }
            ForEach(c.unseenChanges) { ch in
                Text("\(ch.from.text) → \(ch.to.text)").font(Theme.body(13))
                + Text("   spotted \(Day.pretty(ch.date))").font(Theme.body(11)).foregroundColor(Theme.muted)
            }
            Text("A good moment to reach out and congratulate them.").font(Theme.body(12)).foregroundStyle(Theme.muted)
        }
        .padding(14).background(RoundedRectangle(cornerRadius: 10).fill(Theme.tint(.teal)))
    }

    private func statusRow(_ c: Contact) -> some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Stage")
                HStack(spacing: 8) {
                    StageDot(stage: c.stage)
                    Picker("", selection: Binding(get: { c.stage }, set: { v in store.update(id) { $0.stage = v } })) {
                        ForEach(Vocab.stages, id: \.self) { Text($0) }
                    }
                    .labelsHidden().frame(width: 180)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Check-in reminder")
                HStack(spacing: 8) {
                    Button { showCalendar = true } label: {
                        Label(c.nextFollowUp.isEmpty ? "None" : Day.pretty(c.nextFollowUp), systemImage: "calendar")
                            .font(Theme.body(13))
                    }
                    .popover(isPresented: $showCalendar, arrowEdge: .bottom) { reminderPicker(c) }
                    DuePill(contact: c)
                }
            }
            if !c.lastContact.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Last touchpoint")
                    Text("\(Day.pretty(c.lastContact)) · \(Day.relative(c.lastContact))").font(Theme.body(13))
                    Text("\(c.interactions.count) touchpoint\(c.interactions.count == 1 ? "" : "s") logged").font(Theme.body(12)).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private func setReminder(_ s: String) { store.update(id) { $0.nextFollowUp = s }; showCalendar = false }

    /// Calendar for the check-in reminder, with the usual quick picks underneath.
    private func reminderPicker(_ c: Contact) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker("", selection: Binding(
                get: { Day.date(c.nextFollowUp) ?? Date() },
                set: { d in store.update(id) { $0.nextFollowUp = Day.string(d) } }),
                       displayedComponents: .date)
                .labelsHidden().datePickerStyle(.graphical)
            HStack(spacing: 6) {
                Button("+1w") { setReminder(Day.add(days: 7)) }
                Button("+2w") { setReminder(Day.add(days: 14)) }
                Button("+1m") { setReminder(Day.add(months: 1)) }
                Button("+3m") { setReminder(Day.add(months: 3)) }
                Spacer()
                Button("No reminder") { setReminder("") }.disabled(c.nextFollowUp.isEmpty)
            }
            .font(Theme.body(12))
        }
        .padding(14).frame(width: 300)
    }

    private func contactInfo(_ c: Contact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Contact details")
            infoRow("Email", c.email)
            infoRow("Phone", c.phone)
            if !c.linkedin.isEmpty, let u = URL(string: c.linkedin) {
                HStack(spacing: 10) {
                    Text("LinkedIn").font(Theme.body(12)).foregroundStyle(Theme.muted).frame(width: 64, alignment: .leading)
                    Link(c.linkedin.replacingOccurrences(of: "https://www.", with: "").replacingOccurrences(of: "https://", with: ""), destination: u)
                        .font(Theme.body(13))
                }
            }
            if c.email.isEmpty && c.phone.isEmpty {
                Text("No email or phone yet. Use Edit to add them.").font(Theme.body(12)).foregroundStyle(Theme.muted)
            }
            if !c.tags.isEmpty {
                HStack(spacing: 6) { ForEach(c.tags, id: \.self) { Chip(text: $0) } }
            }
        }
    }

    @ViewBuilder private func infoRow(_ k: String, _ v: String) -> some View {
        if !v.isEmpty {
            HStack(spacing: 10) {
                Text(k).font(Theme.body(12)).foregroundStyle(Theme.muted).frame(width: 64, alignment: .leading)
                Text(v).font(Theme.body(13)).textSelection(.enabled)
                Button("Copy") { copyToClipboard(v) }.buttonStyle(.link).font(Theme.body(12))
            }
        }
    }

    private func notes(_ c: Contact) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Your notes")
            Text(c.notes).font(Theme.body(13)).textSelection(.enabled)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.tint(.yellow)))
        }
    }

    private func notesForClaude(_ c: Contact) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes for Claude").font(Theme.title(16))
            Text("Tell Claude where this person belongs, or what only you know: how you know each other, first name or formal, anything to avoid, whether they have seen you work. Then ask Claude to process your notes.")
                .font(Theme.body(12)).foregroundStyle(Theme.muted)
            ForEach(c.classNotes.sorted { ($0.at ?? $0.date) > ($1.at ?? $1.date) }) { n in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(Day.pretty(n.date)).font(Theme.body(11)).foregroundStyle(Theme.muted)
                        Chip(text: n.isOpen ? "Open" : "Done" + (n.doneAt.map { " \(Day.pretty($0))" } ?? ""),
                             color: n.isOpen ? .purple : .green)
                        Spacer()
                        if n.isOpen {
                            Button("Remove") { store.update(id) { x in x.classNotes.removeAll { $0.id == n.id } } }
                                .buttonStyle(.link).font(Theme.body(12))
                        }
                    }
                    Text(n.text).font(Theme.body(13)).textSelection(.enabled)
                    if let r = n.result { Text("Claude: \(r)").font(Theme.body(12)).foregroundStyle(Theme.muted) }
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(n.isOpen ? Theme.tint(.purple) : Theme.quiet))
            }
            TextEditor(text: $noteText)
                .font(Theme.body(13)).frame(minHeight: 60)
                .scrollContentBackground(.hidden).padding(6)
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.5)))
            HStack {
                Spacer()
                Button("Save note for Claude") {
                    let t = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    let n = ClassNote(id: newID(), date: Day.today(), text: t, status: "open", at: Day.nowISO())
                    if store.update(id, { $0.classNotes.append(n) }) { noteText = "" }
                }
                .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.purple.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    private func logForm(_ c: Contact) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log a touchpoint").font(Theme.title(16))
            HStack(spacing: 14) {
                labeled("Date") { DatePicker("", selection: $logDate, displayedComponents: .date).labelsHidden().datePickerStyle(.field) }
                labeled("Channel") { Picker("", selection: $logType) { ForEach(Vocab.channels, id: \.self) { Text($0) } }.labelsHidden() }
                labeled("Stage after this") { Picker("", selection: $logStage) { ForEach(Vocab.stages, id: \.self) { Text($0) } }.labelsHidden() }
            }
            HStack(spacing: 14) {
                labeled("Ask") {
                    Picker("", selection: $logAsk) { Text("Not outreach").tag(""); ForEach(Vocab.asks, id: \.self) { Text($0).tag($0) } }.labelsHidden()
                }
                labeled("Outreach status") {
                    Picker("", selection: $logStatus) { Text("None").tag(""); ForEach(Vocab.statuses, id: \.self) { Text($0).tag($0) } }.labelsHidden()
                }
            }
            labeled("What happened") {
                TextEditor(text: $logSummary).font(Theme.body(13)).frame(minHeight: 60)
                    .scrollContentBackground(.hidden).padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.paper))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
            }
            HStack(alignment: .bottom) {
                labeled("Remind me to check in") {
                    HStack(spacing: 8) {
                        Toggle("", isOn: $remindOn).labelsHidden().toggleStyle(.checkbox)
                        DatePicker("", selection: $remindDate, displayedComponents: .date).labelsHidden().datePickerStyle(.field).disabled(!remindOn)
                        ForEach([("+1w", 7, 0), ("+2w", 14, 0), ("+1m", 0, 1), ("+3m", 0, 3)], id: \.0) { (t, d, m) in
                            Button(t) {
                                remindOn = true
                                remindDate = d > 0 ? Calendar.current.date(byAdding: .day, value: d, to: Date())!
                                                   : Calendar.current.date(byAdding: .month, value: m, to: Date())!
                            }.font(Theme.body(12))
                        }
                    }
                }
                Spacer()
                Button("Log touchpoint") { log() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(logSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.tint(.teal)))
    }

    private func labeled<V: View>(_ t: String, @ViewBuilder _ v: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 5) { SectionLabel(text: t); v() }
    }

    private func log() {
        let s = logSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        let entry = Interaction(id: newID(), date: Day.string(logDate), type: logType, summary: s, at: Day.nowISO(),
                                ask: logAsk.isEmpty ? nil : logAsk, status: logStatus.isEmpty ? nil : logStatus)
        let next = remindOn ? Day.string(remindDate) : ""
        let stage = logStage
        if store.update(id, { x in x.interactions.append(entry); x.stage = stage; x.nextFollowUp = next }) {
            logSummary = ""; logAsk = ""; logStatus = ""; logDate = Date()
            remindOn = true; remindDate = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        }
    }

    private func history(_ c: Contact) -> some View {
        struct Item: Identifiable { let id: String; let date: String; let type: String; let summary: String; let ask: String?; let status: String?; let removable: Bool; let at: String }
        let items: [Item] = c.interactions.map { Item(id: $0.id, date: $0.date, type: $0.type, summary: $0.summary, ask: $0.ask, status: $0.status, removable: true, at: $0.at ?? "") }
            + c.changes.map { Item(id: "chg-" + $0.id, date: $0.date, type: "LinkedIn update", summary: "\($0.from.text) → \($0.to.text)", ask: nil, status: nil, removable: false, at: "") }
        let sorted = items.sorted { ($0.date, $0.at) > ($1.date, $1.at) }
        return VStack(alignment: .leading, spacing: 12) {
            Text("History").font(Theme.title(16))
            if sorted.isEmpty { Text("No touchpoints logged yet.").font(Theme.body(13)).foregroundStyle(Theme.muted) }
            ForEach(sorted) { i in
                HStack(alignment: .top, spacing: 12) {
                    Circle().strokeBorder(Theme.accent, lineWidth: 2).frame(width: 11, height: 11).padding(.top, 4)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(i.type).font(Theme.body(13, .semibold))
                            Text(Day.pretty(i.date)).font(Theme.body(12)).foregroundStyle(Theme.muted)
                            if let a = i.ask { Chip(text: a, color: .teal) }
                            if let s = i.status { Chip(text: s, color: .teal) }
                            Spacer()
                            if i.removable {
                                Button("Remove") { store.update(id) { x in x.interactions.removeAll { $0.id == i.id } } }
                                    .buttonStyle(.link).font(Theme.body(11))
                            }
                        }
                        Text(i.summary).font(Theme.body(13)).textSelection(.enabled)
                    }
                }
            }
        }
    }
}

struct NetworkSection: View {
    let net: Net
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Network list").font(Theme.title(16))
                ScoreBadge(score: Int(net.score) ?? 0)
                if let r = net.rank { Text("#\(r) in \(net.list)").font(Theme.body(12)).foregroundStyle(Theme.muted) }
            }
            if !net.why.isEmpty { Text(net.why).font(Theme.body(13)) }
            if net.score == "5" {
                Text("Before sending: check the live profile for a recent post, a shared group or a mutual connection.")
                    .font(Theme.body(12)).padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.tint(.yellow)))
            }
            ForEach(net.lines.keys.sorted { ($0 == "en" ? 0 : 1, $0) < ($1 == "en" ? 0 : 1, $1) }.filter { !(net.lines[$0] ?? "").isEmpty }, id: \.self) { lang in
                let text = net.lines[lang] ?? ""
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(lang.uppercased()) · \(text.split(separator: " ").count) words").font(Theme.label()).tracking(0.6).foregroundStyle(Theme.accent)
                        Spacer()
                        Button("Copy") { copyToClipboard(text) }.font(Theme.body(12))
                    }
                    Text(text).font(Theme.body(13)).textSelection(.enabled)
                }
                .padding(12).background(RoundedRectangle(cornerRadius: 8).fill(Theme.quiet))
            }
            Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 6) {
                if !net.size.isEmpty { GridRow { k("Company size"); v(net.size) } }
                if !net.signals.isEmpty { GridRow { k("Signals"); v(net.signals) } }
                if !net.order.isEmpty { GridRow { k("Contact order"); v(net.order) } }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
    }
    private func k(_ s: String) -> some View { Text(s).font(Theme.body(12)).foregroundStyle(Theme.muted) }
    private func v(_ s: String) -> some View { Text(s).font(Theme.body(12)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
}

import SwiftUI

struct EditSheet: View {
    let contact: Contact?
    let onSave: (Contact) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var company = ""
    @State private var role = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var linkedin = ""
    @State private var stage = Vocab.defaultStage
    @State private var tags = ""
    @State private var notes = ""
    @State private var hasReminder = false
    @State private var reminder = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(contact == nil ? "New contact" : "Edit contact").font(Theme.title(20))
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow { f("Name", $name); f("Stage") { Picker("", selection: $stage) { ForEach(Vocab.stages, id: \.self) { Text($0) } }.labelsHidden() } }
                GridRow { f("Company", $company); f("Role", $role) }
                GridRow { f("Email", $email); f("Phone", $phone) }
                GridRow { f("LinkedIn URL", $linkedin); f("Check-in reminder") {
                    HStack { Toggle("", isOn: $hasReminder).labelsHidden().toggleStyle(.checkbox)
                        DatePicker("", selection: $reminder, displayedComponents: .date).labelsHidden().datePickerStyle(.field).disabled(!hasReminder) }
                } }
            }
            f("Tags, comma separated", $tags)
            VStack(alignment: .leading, spacing: 5) {
                SectionLabel(text: "Your notes")
                TextEditor(text: $notes).font(Theme.body(13)).frame(minHeight: 90)
                    .scrollContentBackground(.hidden).padding(6)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(contact == nil ? "Add contact" : "Save") { save() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .font(Theme.body(13))
        .padding(24)
        .frame(width: 620)
        .onAppear {
            guard let c = contact else { return }
            name = c.name; company = c.company; role = c.role; email = c.email; phone = c.phone
            linkedin = c.linkedin; stage = c.stage; tags = c.tags.joined(separator: ", "); notes = c.notes
            if let d = Day.date(c.nextFollowUp) { hasReminder = true; reminder = d }
        }
    }

    private func f(_ label: String, _ text: Binding<String>) -> some View {
        f(label) { TextField("", text: text).textFieldStyle(.roundedBorder) }
    }
    private func f<V: View>(_ label: String, @ViewBuilder _ v: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 5) { SectionLabel(text: label); v() }
    }

    private func save() {
        var c = contact ?? Contact(id: "c-" + newID())
        c.name = name.trimmingCharacters(in: .whitespaces)
        c.company = company.trimmingCharacters(in: .whitespaces)
        c.role = role.trimmingCharacters(in: .whitespaces)
        c.email = email.trimmingCharacters(in: .whitespaces)
        c.phone = phone.trimmingCharacters(in: .whitespaces)
        c.linkedin = linkedin.trimmingCharacters(in: .whitespaces)
        c.stage = stage
        c.tags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        c.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        c.nextFollowUp = hasReminder ? Day.string(reminder) : ""
        onSave(c)
        dismiss()
    }
}

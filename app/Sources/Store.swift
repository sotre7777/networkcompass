import Foundation
import Combine
import AppKit

/// Owns the data file. Every change re-reads the file first and writes it back atomically, so edits
/// made by Claude (processing notes, a new LinkedIn export) while the app is open are never overwritten.
@MainActor
final class Store: ObservableObject {
    @Published private(set) var contacts: [Contact] = []
    @Published var loadError: String?
    @Published private(set) var config = CRMConfig()

    private(set) var url: URL
    private var lastModified: Date?
    private var timer: Timer?

    static let defaultPath = NSHomeDirectory() + "/Documents/Network Compass/crm.json"

    init() {
        let path = UserDefaults.standard.string(forKey: "dataPath") ?? Store.defaultPath
        url = URL(fileURLWithPath: path)
        load()
        // Pick up changes Claude makes to the file while the app is open
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reloadIfChanged() }
        }
    }

    private func modDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    private func readFile() throws -> CRMFile {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CRMFile.self, from: data)
    }

    func load() {
        do {
            if !FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try write(CRMFile(config: CRMConfig()))
            }
            apply(try readFile())
            lastModified = modDate()
            loadError = nil
        } catch {
            loadError = "Could not read \(url.path): \(error.localizedDescription)"
        }
    }

    func reloadIfChanged() {
        guard let m = modDate(), m != lastModified else { return }
        load()
        Reminders.shared.refresh(contacts)
    }

    private func apply(_ f: CRMFile) {
        let conf = f.config ?? CRMConfig()
        Vocab.config = conf
        config = conf
        contacts = f.contacts.map { c in
            var c = c
            if c.stage.isEmpty { c.stage = conf.defaultStage }
            return c
        }
    }

    func useFile(_ newURL: URL) {
        UserDefaults.standard.set(newURL.path, forKey: "dataPath")
        url = newURL
        lastModified = nil
        load()
        Reminders.shared.refresh(contacts)
    }

    private func write(_ f: CRMFile) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        let data = try enc.encode(f)
        try data.write(to: url, options: .atomic)
        lastModified = modDate()
    }

    /// Read the latest file, apply the change to one contact, write it back.
    @discardableResult
    func update(_ id: String, _ change: (inout Contact) -> Void) -> Bool {
        do {
            var f = try readFile()
            guard let i = f.contacts.firstIndex(where: { $0.id == id }) else { return false }
            change(&f.contacts[i])
            f.contacts[i].updatedAt = Day.nowISO()
            try write(f)
            apply(f)
            Reminders.shared.refresh(contacts)
            return true
        } catch {
            loadError = "Could not save: \(error.localizedDescription)"
            return false
        }
    }

    func add(_ c: Contact) -> String? {
        do {
            var f = try readFile()
            var n = c
            n.createdAt = Day.nowISO(); n.updatedAt = n.createdAt
            f.contacts.append(n)
            try write(f)
            apply(f)
            return n.id
        } catch {
            loadError = "Could not save: \(error.localizedDescription)"
            return nil
        }
    }

    func delete(_ id: String) {
        do {
            var f = try readFile()
            f.contacts.removeAll { $0.id == id }
            try write(f)
            apply(f)
            Reminders.shared.refresh(contacts)
        } catch {
            loadError = "Could not delete: \(error.localizedDescription)"
        }
    }

    /// Change lists, stages or their colors. `rewrite` updates the contacts that used an old name.
    func updateConfig(rewrite: ((inout Contact) -> Void)? = nil, _ change: (inout CRMConfig) -> Void) {
        do {
            var f = try readFile()
            var conf = f.config ?? CRMConfig()
            change(&conf)
            f.config = conf
            if let rewrite { for i in f.contacts.indices { rewrite(&f.contacts[i]) } }
            try write(f)
            apply(f)
        } catch {
            loadError = "Could not save settings: \(error.localizedDescription)"
        }
    }

    func setList(_ id: String, _ list: String?) {
        update(id) { c in
            if let list {
                if c.net == nil { c.net = Net(list: list) } else { c.net?.list = list }
            } else {
                c.net = nil
            }
            c.netLocked = true
        }
    }

    func contact(_ id: String?) -> Contact? {
        guard let id else { return nil }
        return contacts.first { $0.id == id }
    }
}

// MARK: - Check-in state

enum Due: Int { case overdue, today, week, later, none }

extension Contact {
    var due: Due {
        guard !nextFollowUp.isEmpty else { return .none }
        let d = Day.between(Day.today(), nextFollowUp)
        return d < 0 ? .overdue : d == 0 ? .today : d <= 7 ? .week : .later
    }
    var isCold: Bool {
        guard stage != Vocab.config.stages.last?.name, !lastContact.isEmpty else { return false }
        return Day.between(lastContact, Day.today()) > 60
    }
    var dueLabel: String {
        switch due {
        case .none: return ""
        case .overdue: return "overdue \(-Day.between(Day.today(), nextFollowUp))d"
        case .today: return "check in today"
        case .week, .later: return Day.pretty(nextFollowUp)
        }
    }
}

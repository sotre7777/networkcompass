import Foundation

// One contact as stored in data/crm.json. The Python scripts and Claude's note processing
// work on the same file: see docs/data-format.md.

struct Job: Codable, Hashable {
    var company: String = ""
    var position: String = ""
    init(company: String = "", position: String = "") { self.company = company; self.position = position }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        company = try c.decodeIfPresent(String.self, forKey: .company) ?? ""
        position = try c.decodeIfPresent(String.self, forKey: .position) ?? ""
    }
    var text: String { [position, company].filter { !$0.isEmpty }.joined(separator: " at ").ifEmpty("no role listed") }
}

struct Interaction: Codable, Hashable, Identifiable {
    var id: String
    var date: String
    var type: String
    var summary: String
    var at: String?
    var ask: String?
    var status: String?
}

struct JobChange: Codable, Hashable, Identifiable {
    var id: String
    var date: String
    var from: Job
    var to: Job
    var seen: Bool
}

/// What the network analysis decided about this person, or where they were moved by hand.
struct Net: Codable, Hashable {
    var list: String = ""
    var rank: Int?
    var score: String = ""
    var category: String = ""
    var why: String = ""
    var size: String = ""
    var signals: String = ""
    var order: String = ""
    var lines: [String: String] = [:]
    init(list: String) { self.list = list }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        list = try c.decodeIfPresent(String.self, forKey: .list) ?? ""
        rank = try c.decodeIfPresent(Int.self, forKey: .rank)
        if let s = try? c.decode(String.self, forKey: .score) { score = s }
        else if let i = try? c.decode(Int.self, forKey: .score) { score = String(i) }
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        why = try c.decodeIfPresent(String.self, forKey: .why) ?? ""
        size = try c.decodeIfPresent(String.self, forKey: .size) ?? ""
        signals = try c.decodeIfPresent(String.self, forKey: .signals) ?? ""
        order = try c.decodeIfPresent(String.self, forKey: .order) ?? ""
        lines = try c.decodeIfPresent([String: String].self, forKey: .lines) ?? [:]
    }
}

/// An instruction to Claude about where this contact belongs, or context only the user has.
struct ClassNote: Codable, Hashable, Identifiable {
    var id: String
    var date: String
    var text: String
    var status: String          // "open" or "done"
    var at: String?
    var result: String?
    var doneAt: String?
    var isOpen: Bool { status != "done" }
}

struct Contact: Codable, Hashable, Identifiable {
    var id: String
    var name: String = ""
    var company: String = ""
    var role: String = ""
    var email: String = ""
    var phone: String = ""
    var linkedin: String = ""
    var stage: String = ""
    var tags: [String] = []
    var notes: String = ""
    var nextFollowUp: String = ""
    var interactions: [Interaction] = []
    var li: Job?
    var changes: [JobChange] = []
    var connectedOn: String?
    var net: Net?
    var netLocked: Bool?        // moved by hand: a later export leaves the list alone
    var classNotes: [ClassNote] = []
    var createdAt: String?
    var updatedAt: String?

    init(id: String) { self.id = id }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        company = try c.decodeIfPresent(String.self, forKey: .company) ?? ""
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
        linkedin = try c.decodeIfPresent(String.self, forKey: .linkedin) ?? ""
        stage = try c.decodeIfPresent(String.self, forKey: .stage) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        nextFollowUp = try c.decodeIfPresent(String.self, forKey: .nextFollowUp) ?? ""
        interactions = try c.decodeIfPresent([Interaction].self, forKey: .interactions) ?? []
        li = try c.decodeIfPresent(Job.self, forKey: .li)
        changes = try c.decodeIfPresent([JobChange].self, forKey: .changes) ?? []
        connectedOn = try c.decodeIfPresent(String.self, forKey: .connectedOn)
        net = try c.decodeIfPresent(Net.self, forKey: .net)
        netLocked = try c.decodeIfPresent(Bool.self, forKey: .netLocked)
        classNotes = try c.decodeIfPresent([ClassNote].self, forKey: .classNotes) ?? []
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    // Derived
    var lastContact: String { interactions.map(\.date).max() ?? "" }
    var openNotes: [ClassNote] { classNotes.filter(\.isOpen) }
    var unseenChanges: [JobChange] { changes.filter { !$0.seen } }
    var listName: String { net?.list ?? "" }
    var score: Int { Int(net?.score ?? "") ?? 0 }
    var subtitle: String { [role, company].filter { !$0.isEmpty }.joined(separator: " · ") }
    var isLeader: Bool {
        role.range(of: Vocab.config.leaderPattern, options: [.regularExpression, .caseInsensitive]) != nil
            && role.range(of: "assistant", options: .caseInsensitive) == nil
    }
}

struct NamedColor: Codable, Hashable, Identifiable {
    var name: String
    var color: String
    var source: String?         // which analysis list this is, so a rename survives a re-run
    var id: String { name }
}

/// Everything a user can name for themselves. Lives in the data file; edited in Settings.
struct CRMConfig: Codable, Equatable {
    var lists: [NamedColor] = []
    var stages: [NamedColor] = [NamedColor(name: "Active", color: "red"), NamedColor(name: "Prospect", color: "yellow"),
                                NamedColor(name: "Assess", color: "purple"), NamedColor(name: "Keep in touch", color: "green"),
                                NamedColor(name: "Dormant", color: "gray")]
    var defaultStage = "Keep in touch"
    var asks = ["Conversation", "Referral", "Proposal"]
    var statuses = ["Sent", "Followed up", "No reply", "Declined", "Replied", "Talked", "Lead shared", "Closed"]
    var sentStatus = "Sent"
    var repliedStatuses = ["Replied", "Talked", "Lead shared", "Closed"]
    var talkedStatus = "Talked"
    var referralStatus = "Lead shared"
    var proposalAsk = "Proposal"
    var proposalLabel = "Proposals made"
    var leaderPattern = #"\b(chief|ceo|coo|cfo|cto|cmo|cro|cpo|cio|founder|co-?founder|president|vp|vice president|svp|evp|general manager|managing director|head of|senior director|managing partner|chair|chairman|chairwoman)\b"#
}

struct CRMFile: Codable {
    var version: Int = 2
    var config: CRMConfig?
    var contacts: [Contact] = []
}

/// The current configuration, set by Store whenever the file loads.
enum Vocab {
    static var config = CRMConfig()
    static var stages: [String] { config.stages.map(\.name) }
    static var lists: [String] { config.lists.map(\.name) }
    static var asks: [String] { config.asks }
    static var statuses: [String] { config.statuses }
    static var defaultStage: String { config.defaultStage }
    static let channels = ["Email", "Call", "Meeting", "Coffee", "LinkedIn", "Event", "Intro", "Message", "Other"]
}

extension String {
    func ifEmpty(_ s: String) -> String { isEmpty ? s : self }
}

enum Day {
    static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func today() -> String { fmt.string(from: Date()) }
    static func date(_ s: String) -> Date? { fmt.date(from: s) }
    static func string(_ d: Date) -> String { fmt.string(from: d) }
    static func add(days: Int, to s: String = today()) -> String {
        Calendar.current.date(byAdding: .day, value: days, to: date(s) ?? Date()).map(string) ?? s
    }
    static func add(months: Int, to s: String = today()) -> String {
        Calendar.current.date(byAdding: .month, value: months, to: date(s) ?? Date()).map(string) ?? s
    }
    /// Days from a to b
    static func between(_ a: String, _ b: String) -> Int {
        guard let x = date(a), let y = date(b) else { return 0 }
        return Calendar.current.dateComponents([.day], from: x, to: y).day ?? 0
    }
    static func pretty(_ s: String) -> String {
        guard let d = date(s) else { return s }
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDate(d, equalTo: Date(), toGranularity: .year) ? "d MMM" : "d MMM yyyy"
        return f.string(from: d)
    }
    static func relative(_ s: String) -> String {
        let n = between(s, today())
        switch n {
        case 0: return "today"
        case 1: return "yesterday"
        case -1: return "tomorrow"
        default: return n > 0 ? "\(n)d ago" : "in \(-n)d"
        }
    }
    static func nowISO() -> String { ISO8601DateFormatter().string(from: Date()) }
}

func newID() -> String { String(UUID().uuidString.prefix(8)).lowercased() }

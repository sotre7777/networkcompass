import SwiftUI

/// System colors and fonts, so the app follows light and dark mode.
enum Theme {
    static let accent = Color.accentColor
    static let ink = Color.primary
    static let muted = Color.secondary
    static let line = Color.secondary.opacity(0.25)
    static let paper = Color(nsColor: .textBackgroundColor)
    static let quiet = Color.secondary.opacity(0.1)

    static func body(_ size: CGFloat = 13, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
    static func title(_ size: CGFloat = 22) -> Font { .system(size: size, weight: .bold) }
    static func label() -> Font { .system(size: 10.5, weight: .semibold) }

    static func named(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "yellow": return .yellow
        case "purple": return .purple
        case "indigo": return .indigo
        case "teal": return .teal
        case "pink": return .pink
        default: return .gray
        }
    }
    static let colorNames = ["blue", "green", "orange", "red", "yellow", "purple", "indigo", "teal", "pink", "gray"]

    static func stageColor(_ s: String) -> Color { named(Vocab.config.stages.first { $0.name == s }?.color ?? "gray") }
    static func listColor(_ l: String) -> Color { named(Vocab.config.lists.first { $0.name == l }?.color ?? "gray") }
    static func tint(_ c: Color) -> Color { c.opacity(0.16) }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(Theme.label()).tracking(0.8).foregroundStyle(Theme.muted)
    }
}

struct Chip: View {
    let text: String
    var color: Color = .secondary
    var body: some View {
        Text(text).font(Theme.body(11, .medium)).foregroundStyle(color == .secondary ? Theme.muted : Theme.ink)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(Theme.tint(color)))
    }
}

struct ScoreBadge: View {
    let score: Int
    var body: some View {
        if score > 0 {
            Text("\(score)").font(Theme.body(11, .semibold)).monospacedDigit()
                .foregroundStyle(score >= 5 ? Color.white : Theme.ink)
                .frame(minWidth: 20, minHeight: 20)
                .background(RoundedRectangle(cornerRadius: 5).fill(score >= 5 ? Theme.accent : Theme.quiet))
                .help("Network score")
        }
    }
}

struct DuePill: View {
    let contact: Contact
    var body: some View {
        switch contact.due {
        case .none: EmptyView()
        case .overdue: Chip(text: contact.dueLabel, color: .red)
        case .today, .week: Chip(text: contact.dueLabel, color: .yellow)
        case .later: Chip(text: contact.dueLabel)
        }
    }
}

struct StageDot: View {
    let stage: String
    var size: CGFloat = 9
    var body: some View { Circle().fill(Theme.stageColor(stage)).frame(width: size, height: size).help(stage) }
}

func copyToClipboard(_ s: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(s, forType: .string)
}

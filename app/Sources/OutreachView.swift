import SwiftUI

/// Outreach results computed from logged touchpoints (replaces the old outreach_tracker.csv).
struct OutreachView: View {
    @EnvironmentObject var store: Store

    struct Row { var list: String; var cat: String; var sent = 0; var reached = 0; var replied = 0; var talked = 0; var referrals = 0; var sessions = 0 }
    struct Totals { var sent = 0, reached = 0, replied = 0, talked = 0, referrals = 0, sessions = 0
        var rate: String { reached > 0 ? "\(Int((Double(replied) / Double(reached) * 100).rounded()))%" : "–" } }

    private var rows: [Row] {
        store.contacts.compactMap { c in
            let ints = c.interactions
            guard ints.contains(where: { $0.status != nil }) else { return nil }
            let conf = Vocab.config
            let sent = ints.filter { $0.status == conf.sentStatus }.count
            return Row(list: c.net?.list ?? "Not on the lists", cat: c.net?.category.ifEmpty("–") ?? "–",
                       sent: sent, reached: sent > 0 ? 1 : 0,
                       replied: ints.contains { conf.repliedStatuses.contains($0.status ?? "") } ? 1 : 0,
                       talked: ints.contains { $0.status == conf.talkedStatus } ? 1 : 0,
                       referrals: ints.filter { $0.status == conf.referralStatus }.count,
                       sessions: ints.filter { $0.ask == conf.proposalAsk && $0.status == conf.sentStatus }.count)
        }
    }

    private func total(_ rs: [Row]) -> Totals {
        rs.reduce(into: Totals()) { t, r in
            t.sent += r.sent; t.reached += r.reached; t.replied += r.replied
            t.talked += r.talked; t.referrals += r.referrals; t.sessions += r.sessions
        }
    }

    var body: some View {
        let rs = rows, t = total(rs)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Outreach results").font(Theme.title(22))
                HStack(spacing: 10) {
                    tile("\(t.sent)", "Messages sent", .teal)
                    tile(t.rate, "Reply rate", .purple)
                    tile("\(t.talked)", "Conversations held", .green)
                    tile("\(t.referrals)", "Referrals received", .orange)
                    tile("\(t.sessions)", Vocab.config.proposalLabel, .yellow)
                }
                Text(t.reached == 0
                     ? "Nothing logged yet. When you send a message, log a touchpoint with its outreach status and Ask. Log replies the same way."
                     : "Based on \(t.reached) \(t.reached == 1 ? "person" : "people") you messaged." + (t.reached < 20 ? " That is too few to read much into yet." : ""))
                    .font(Theme.body(13)).foregroundStyle(Theme.muted)
                table("By list", Dictionary(grouping: rs, by: \.list))
                table("By category", Dictionary(grouping: rs, by: \.cat))
            }
            .padding(24)
        }
        .background(Theme.paper)
        .foregroundStyle(Theme.ink)
    }

    private func tile(_ n: String, _ l: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(n).font(Theme.title(24)).monospacedDigit()
            Text(l.uppercased()).font(Theme.label()).tracking(0.6).foregroundStyle(Theme.muted)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.tint(color)))
    }

    @ViewBuilder private func table(_ title: String, _ groups: [String: [Row]]) -> some View {
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: title)
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                    GridRow { ForEach(["", "Messages", "People", "Replied", "Reply rate", "Talked", "Referrals"], id: \.self) {
                        Text($0).font(Theme.body(11, .semibold)).foregroundStyle(Theme.muted) } }
                    ForEach(groups.keys.sorted(), id: \.self) { k in
                        let t = total(groups[k]!)
                        GridRow {
                            Text(k).font(Theme.body(13))
                            num(t.sent); num(t.reached); num(t.replied)
                            Text(t.rate + (t.reached > 0 && t.reached < 10 ? " (n=\(t.reached))" : "")).font(Theme.body(13)).monospacedDigit()
                            num(t.talked); num(t.referrals)
                        }
                    }
                }
            }
        }
    }
    private func num(_ n: Int) -> some View { Text("\(n)").font(Theme.body(13)).monospacedDigit() }
}

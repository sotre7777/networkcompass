import Foundation
import AppKit
import UserNotifications

/// Check-in reminders that reach you outside the app: one notification at 9:00 on each day
/// someone is due, and a Dock badge with the number due today or overdue.
@MainActor
final class Reminders {
    static let shared = Reminders()
    private let center = UNUserNotificationCenter.current()
    private var authorized = false
    static let hour = 9

    func requestAccess() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
            Task { @MainActor in self.authorized = ok }
        }
    }

    func refresh(_ contacts: [Contact]) {
        let dueNow = contacts.filter { $0.due == .overdue || $0.due == .today }.count
        NSApp?.dockTile.badgeLabel = dueNow > 0 ? "\(dueNow)" : nil

        // Group upcoming reminders by day, then schedule one notification per day (macOS keeps 64 at most)
        var byDay: [String: [String]] = [:]
        let today = Day.today()
        for c in contacts where !c.nextFollowUp.isEmpty && c.nextFollowUp >= today {
            byDay[c.nextFollowUp, default: []].append(c.name)
        }
        center.removeAllPendingNotificationRequests()
        for day in byDay.keys.sorted().prefix(60) {
            guard let date = Day.date(day) else { continue }
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
            comps.hour = Reminders.hour
            if day == today, Calendar.current.component(.hour, from: Date()) >= Reminders.hour { continue }
            let names = byDay[day]!.sorted()
            let content = UNMutableNotificationContent()
            content.title = names.count == 1 ? "Check in with \(names[0])" : "\(names.count) check-ins today"
            content.body = names.count == 1 ? "Your reminder in Network Compass."
                : names.prefix(4).joined(separator: ", ") + (names.count > 4 ? " and \(names.count - 4) more" : "")
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: "checkin-\(day)", content: content, trigger: trigger))
        }
    }
}

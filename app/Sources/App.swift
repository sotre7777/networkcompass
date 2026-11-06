import SwiftUI
import AppKit

@main
struct NetworkCompassApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup("Network Compass", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1000, minHeight: 640)
                .onAppear { Reminders.shared.refresh(store.contacts) }
        }
        .defaultSize(width: 1320, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Contact") { NotificationCenter.default.post(name: .newContact, object: nil) }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("Stage") {
                ForEach(Array(store.config.stages.prefix(9).map(\.name).enumerated()), id: \.offset) { i, s in
                    Button(s) { NotificationCenter.default.post(name: .setStage, object: s) }
                        .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: .command)
                }
            }
            CommandGroup(after: .toolbar) {
                Button("Reload Data") { store.load() }.keyboardShortcut("r", modifiers: .command)
            }
        }

        Window("Outreach Results", id: "outreach") {
            OutreachView().environmentObject(store)
        }
        .defaultSize(width: 760, height: 560)
        .keyboardShortcut("o", modifiers: [.command, .shift])

        Settings {
            SettingsView().environmentObject(store)
        }

        // Today's check-ins in the menu bar
        MenuBarExtra {
            MenuBarContent().environmentObject(store)
        } label: {
            let n = store.contacts.filter { $0.due == .overdue || $0.due == .today }.count
            Image(systemName: n > 0 ? "person.crop.circle.badge.clock" : "person.crop.circle")
            if n > 0 { Text("\(n)") }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in Reminders.shared.requestAccess() }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct MenuBarContent: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        let due = store.contacts.filter { $0.due == .overdue || $0.due == .today }.sorted { $0.nextFollowUp < $1.nextFollowUp }
        if due.isEmpty { Text("No check-ins due today") }
        else { Text("Check in today").font(.headline) }
        ForEach(due.prefix(15)) { c in
            Button("\(c.name)\(c.due == .overdue ? " · overdue" : "")") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: .openContact, object: c.id)
            }
        }
        Divider()
        Button("Open Network Compass") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
        Button("Outreach Results") { openWindow(id: "outreach"); NSApp.activate(ignoringOtherApps: true) }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var app: AppState
    @State private var newGroup: String = ""
    @State private var accessibilityGranted = PasteExecutor.hasAccessibilityPermission
    @State private var confirmClearKeepFavorites = false
    @State private var confirmClearAll = false

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gearshape") }
            groupsTab.tabItem { Label("Groups", systemImage: "folder") }
            permissionsTab.tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(width: 480, height: 400)
        .padding()
        .confirmationDialog(
            "Clear history?",
            isPresented: $confirmClearKeepFavorites,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) { app.clearHistory(keepFavorites: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove items that are not pinned and not in any collection. Pinned items and items in collections stay.")
        }
        .confirmationDialog(
            "Clear everything?",
            isPresented: $confirmClearAll,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) { app.clearHistory(keepFavorites: false) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove every saved item, including pinned items and items in collections. This cannot be undone.")
        }
    }

    private var generalTab: some View {
        Form {
            Section("History") {
                Stepper(value: $settings.maxHistoryCount, in: 50...10000, step: 50) {
                    Text("Max history items: \(settings.maxHistoryCount)")
                }
                HStack {
                    Button("Clear history (keep favorites)") { confirmClearKeepFavorites = true }
                    Button("Clear all", role: .destructive) { confirmClearAll = true }
                }
            }
            Section("Paste") {
                Toggle("Restore previous clipboard after paste", isOn: $settings.restorePreviousClipboardAfterPaste)
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0; updateLaunchAtLogin($0) }
                ))
            }
            Section("Monitoring") {
                Slider(value: $settings.pollInterval, in: 0.2...1.0, step: 0.1) {
                    Text("Poll interval")
                } minimumValueLabel: { Text("0.2s") } maximumValueLabel: { Text("1.0s") }
                Text(String(format: "%.1f seconds", settings.pollInterval)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var groupsTab: some View {
        VStack(alignment: .leading) {
            List {
                ForEach(app.groups) { g in
                    HStack {
                        Image(systemName: "folder")
                        Text(g.name)
                        Spacer()
                        Button { app.deleteGroup(g) } label: { Image(systemName: "trash") }
                            .buttonStyle(.plain).foregroundStyle(.red)
                    }
                }
            }
            HStack {
                TextField("New group name", text: $newGroup)
                    .textFieldStyle(.roundedBorder)
                Button("Create") { app.createGroup(name: newGroup); newGroup = "" }
            }
        }
    }

    private var permissionsTab: some View {
        Form {
            Section("Accessibility") {
                HStack {
                    Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(accessibilityGranted ? .green : .red)
                    Text(accessibilityGranted ? "Granted" : "Not granted")
                }
                Text("Required to simulate Cmd+V when pasting history items.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Request / Open System Settings") {
                    PasteExecutor.requestAccessibilityPermission()
                    accessibilityGranted = PasteExecutor.hasAccessibilityPermission
                }
                Button("Re-check") { accessibilityGranted = PasteExecutor.hasAccessibilityPermission }
            }
            Section("Data location") {
                Text(Storage.supportDir.path).font(.caption).textSelection(.enabled)
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([Storage.supportDir])
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Actions

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("ClipboardX: launch at login update failed: \(error)")
        }
    }
}

/// Hosts the settings window.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: SettingsStore
    private let app: AppState

    init(settings: SettingsStore, app: AppState) {
        self.settings = settings
        self.app = app
    }

    func show() {
        if window == nil {
            let view = SettingsView(settings: settings, app: app)
            let hosting = NSHostingController(rootView: view)
            let w = NSWindow(contentViewController: hosting)
            w.title = "ClipboardX Settings"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

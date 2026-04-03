import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var store: RepositoryStore!
    private var poller: PipelinePoller!
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = RepositoryStore()
        poller = PipelinePoller(store: store)

        setupStatusItem()
        setupPopover()

        store.$settings.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.poller.stop()
                self?.poller.start()
            }
        }.store(in: &cancellables)

        poller.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateIcon),
            name: .repositoryStateDidChange,
            object: nil
        )
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        statusItem.button?.action = #selector(handleClick)
        statusItem.button?.target = self
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .applicationDefined
        popover.contentViewController = NSHostingController(
            rootView: MonitorView(store: store)
        )
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showQuitMenu()
        } else {
            togglePopover()
        }
    }

    private func showQuitMenu() {
        closePopover()
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "退出 GitLab Monitor", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    @objc private func updateIcon() {
        Task { @MainActor in
            let status = self.store.overallStatus
            if let image = NSImage(named: "gitlab-icon") {
                image.isTemplate = true
                self.statusItem.button?.image = image
            } else {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                let fallback = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
                    .withSymbolConfiguration(config)
                self.statusItem.button?.image = fallback
            }
            self.statusItem.button?.contentTintColor = NSColor(status.color)
        }
    }
}

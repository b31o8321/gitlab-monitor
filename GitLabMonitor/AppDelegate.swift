import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var store: RepositoryStore!
    private var poller: PipelinePoller!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = RepositoryStore()
        poller = PipelinePoller(store: store)

        setupStatusItem()
        setupPopover()

        // Restart poller and update icon when settings change
        store.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.poller.stop()
                self?.poller.start()
                self?.updateIcon()
            }
        }.store(in: &cancellables)

        poller.start()

        // Listen for state changes to update icon color
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
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MonitorView(store: store)
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc func updateIcon() {
        Task { @MainActor in
            let status = self.store.overallStatus
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
            self.statusItem.button?.image = image
            self.statusItem.button?.contentTintColor = NSColor(status.color)
        }
    }
}


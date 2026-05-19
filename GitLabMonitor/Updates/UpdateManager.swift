import Foundation
import AppKit

@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(UpdateInfo)
        case downloading
        case error(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastCheck: Date?

    private let repo = "b31o8321/gitlab-monitor"
    private let checkInterval: TimeInterval = 6 * 3600
    private let skippedVersionKey = "com.gitlab-monitor.skippedUpdateVersion"
    private var timer: Timer?

    func start() {
        scheduleNext()
        Task { await checkForUpdate(silent: true) }
    }

    private func scheduleNext() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.checkForUpdate(silent: true) }
        }
    }

    func checkForUpdate(silent: Bool) async {
        if case .downloading = state { return }
        state = .checking
        do {
            let info = try await UpdateChecker(repo: repo).checkLatest()
            lastCheck = Date()
            if let info = info {
                let skipped = UserDefaults.standard.string(forKey: skippedVersionKey)
                if silent && info.version == skipped {
                    state = .upToDate
                    return
                }
                state = .updateAvailable(info)
            } else {
                state = .upToDate
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func skipCurrentVersion() {
        if case .updateAvailable(let info) = state {
            UserDefaults.standard.set(info.version, forKey: skippedVersionKey)
            state = .upToDate
        }
    }

    func dismissUpdate() {
        if case .updateAvailable = state {
            state = .upToDate
        }
    }

    func performUpdate() async {
        guard case .updateAvailable(let info) = state else { return }
        guard let dmgUrl = info.dmgUrl else {
            state = .error("此版本没有 DMG 资源")
            return
        }
        state = .downloading
        do {
            let (tmpUrl, _) = try await URLSession.shared.download(from: dmgUrl)
            let cacheDir = try FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let cacheUrl = cacheDir.appendingPathComponent("GitLabMonitor-\(info.version).dmg")
            try? FileManager.default.removeItem(at: cacheUrl)
            try FileManager.default.moveItem(at: tmpUrl, to: cacheUrl)

            let scriptUrl = try writeUpdaterScript(dmgPath: cacheUrl.path)

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [scriptUrl.path]
            try task.run()

            // Brief delay so the script is reading args / sleeping before we exit.
            try await Task.sleep(nanoseconds: 300_000_000)
            NSApplication.shared.terminate(nil)
        } catch {
            state = .error("下载失败：\(error.localizedDescription)")
        }
    }

    private func writeUpdaterScript(dmgPath: String) throws -> URL {
        let cacheDir = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let scriptUrl = cacheDir.appendingPathComponent("gitlab-monitor-updater.sh")
        let mountPoint = "/tmp/gitlab-monitor-update-\(UUID().uuidString)"
        let appPath = Bundle.main.bundleURL.path
        // Shell-quote paths defensively.
        let qDmg = shellQuote(dmgPath)
        let qApp = shellQuote(appPath)
        let qMount = shellQuote(mountPoint)
        let script = """
        #!/bin/bash
        set -e
        DMG=\(qDmg)
        MOUNT=\(qMount)
        APP_DEST=\(qApp)

        # Wait for the running GitLabMonitor to exit (up to ~15s).
        for i in $(seq 1 30); do
            if ! pgrep -x GitLabMonitor > /dev/null; then break; fi
            sleep 0.5
        done

        # Strip quarantine on the DMG itself before mounting.
        xattr -cr "$DMG" 2>/dev/null || true

        mkdir -p "$MOUNT"
        hdiutil attach "$DMG" -nobrowse -quiet -mountpoint "$MOUNT"

        APP_SRC="$MOUNT/GitLabMonitor.app"
        if [ ! -d "$APP_SRC" ]; then
            APP_SRC=$(find "$MOUNT" -maxdepth 2 -type d -name "GitLabMonitor.app" | head -1)
        fi

        if [ -z "$APP_SRC" ] || [ ! -d "$APP_SRC" ]; then
            hdiutil detach "$MOUNT" -quiet -force || true
            rmdir "$MOUNT" 2>/dev/null || true
            exit 1
        fi

        rm -rf "$APP_DEST"
        cp -R "$APP_SRC" "$APP_DEST"
        xattr -cr "$APP_DEST"

        hdiutil detach "$MOUNT" -quiet -force || true
        rmdir "$MOUNT" 2>/dev/null || true
        rm -f "$DMG"

        open "$APP_DEST"
        """
        try script.write(to: scriptUrl, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptUrl.path)
        return scriptUrl
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

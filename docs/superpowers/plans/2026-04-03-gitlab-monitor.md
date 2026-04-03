# GitLab Monitor 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 macOS 原生菜单栏应用，实时监控 GitLab CI/CD Pipeline 状态，通过图标颜色反映整体健康状态。

**Architecture:** 使用 SwiftUI + AppKit 构建无 Dock 图标的菜单栏应用。`PipelinePoller` 定时调用 `GitLabService` 拉取 Pipeline 状态，更新 `RepositoryStore` 后同时驱动菜单栏图标和 SwiftUI 面板刷新。Token 存 Keychain，仓库配置存 UserDefaults。

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, NSStatusItem, Keychain Services, XCTest

---

## 文件结构

```
GitLabMonitor/
├── GitLabMonitorApp.swift          — @main 入口，LSUIElement 配置
├── AppDelegate.swift               — NSStatusItem 创建，Popover 管理
├── Models/
│   ├── Repository.swift            — Repository struct (Codable, Identifiable)
│   ├── AppSettings.swift           — AppSettings struct + UserDefaults 持久化
│   └── PipelineStatus.swift        — PipelineStatus enum + 颜色/文字映射
├── Services/
│   ├── GitLabServiceProtocol.swift — HTTPClient 协议，便于测试 mock
│   ├── GitLabService.swift         — 真实 API 实现
│   └── KeychainService.swift       — Token 的 Keychain 读写
├── Store/
│   └── RepositoryStore.swift       — @MainActor ObservableObject，状态缓存
├── Polling/
│   └── PipelinePoller.swift        — Timer 驱动轮询逻辑
├── Views/
│   ├── MonitorView.swift           — 监控面板主视图
│   ├── RepositoryRowView.swift     — 单个仓库行视图
│   └── SettingsView.swift          — 设置页视图
└── Tests/
    ├── GitLabServiceTests.swift    — API 解析逻辑测试（mock HTTP）
    └── PipelinePollerTests.swift   — 轮询状态更新逻辑测试
```

---

## Task 1: Xcode 项目初始化

**Files:**
- Create: `GitLabMonitor.xcodeproj` (via Xcode)
- Create: `GitLabMonitor/GitLabMonitorApp.swift`
- Create: `GitLabMonitor/Info.plist`

- [ ] **Step 1: 用 Xcode 创建项目**

打开 Xcode → File → New → Project → macOS → App
- Product Name: `GitLabMonitor`
- Bundle Identifier: `com.gitlab-monitor`
- Interface: SwiftUI
- Language: Swift
- 取消勾选 "Include Tests"（后续手动添加）

- [ ] **Step 2: 配置 Info.plist 隐藏 Dock 图标**

在 `Info.plist` 中添加：
```xml
<key>LSUIElement</key>
<true/>
```

- [ ] **Step 3: 修改 GitLabMonitorApp.swift**

```swift
import SwiftUI

@main
struct GitLabMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

- [ ] **Step 4: 构建验证**

Command+B，确认无编译错误。

- [ ] **Step 5: 初始化 git 并提交**

```bash
cd /Users/norman/development/gitlab-monitor
git init
git add .
git commit -m "chore: init Xcode project with LSUIElement"
```

---

## Task 2: 数据模型

**Files:**
- Create: `GitLabMonitor/Models/PipelineStatus.swift`
- Create: `GitLabMonitor/Models/Repository.swift`
- Create: `GitLabMonitor/Models/AppSettings.swift`

- [ ] **Step 1: 创建 PipelineStatus.swift**

```swift
import SwiftUI

enum PipelineStatus: String, Codable {
    case running
    case pending
    case success
    case failed
    case canceled
    case unknown

    var color: Color {
        switch self {
        case .running, .pending: return .yellow
        case .success: return .green
        case .failed: return .red
        case .canceled, .unknown: return .gray
        }
    }

    var label: String {
        switch self {
        case .running: return "运行中"
        case .pending: return "等待中"
        case .success: return "成功"
        case .failed: return "失败"
        case .canceled: return "已取消"
        case .unknown: return "未知"
        }
    }

    var symbol: String {
        switch self {
        case .running: return "↻"
        case .pending: return "…"
        case .success: return "✓"
        case .failed: return "✗"
        case .canceled: return "⊘"
        case .unknown: return "?"
        }
    }
}
```

- [ ] **Step 2: 创建 Repository.swift**

```swift
import Foundation

struct Repository: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var projectPath: String
    var branch: String

    init(id: UUID = UUID(), name: String, projectPath: String, branch: String) {
        self.id = id
        self.name = name
        self.projectPath = projectPath
        self.branch = branch
    }
}
```

- [ ] **Step 3: 创建 AppSettings.swift**

```swift
import Foundation

struct AppSettings: Codable {
    var gitlabUrl: String
    var pollInterval: Int
    var repositories: [Repository]

    static let `default` = AppSettings(
        gitlabUrl: "",
        pollInterval: 60,
        repositories: []
    )

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "appSettings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: "appSettings")
    }
}
```

- [ ] **Step 4: 构建验证**

Command+B，确认无编译错误。

- [ ] **Step 5: 提交**

```bash
git add GitLabMonitor/Models/
git commit -m "feat: add data models (PipelineStatus, Repository, AppSettings)"
```

---

## Task 3: Keychain Service

**Files:**
- Create: `GitLabMonitor/Services/KeychainService.swift`

- [ ] **Step 1: 创建 KeychainService.swift**

```swift
import Foundation
import Security

enum KeychainService {
    private static let key = "com.gitlab-monitor.access-token"

    static func saveToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 2: 构建验证**

Command+B，确认无编译错误。

- [ ] **Step 3: 提交**

```bash
git add GitLabMonitor/Services/KeychainService.swift
git commit -m "feat: add KeychainService for token storage"
```

---

## Task 4: GitLabService（含协议 + 测试）

**Files:**
- Create: `GitLabMonitor/Services/GitLabServiceProtocol.swift`
- Create: `GitLabMonitor/Services/GitLabService.swift`
- Create: `GitLabMonitorTests/GitLabServiceTests.swift`

- [ ] **Step 1: 在 Xcode 添加 Test Target**

File → New → Target → macOS → Unit Testing Bundle
- Product Name: `GitLabMonitorTests`

- [ ] **Step 2: 创建 GitLabServiceProtocol.swift**

```swift
import Foundation

struct PipelineResult {
    let status: PipelineStatus
    let webUrl: String
    let updatedAt: Date
}

protocol GitLabServiceProtocol {
    func fetchLatestPipeline(
        gitlabUrl: String,
        projectPath: String,
        branch: String,
        token: String
    ) async throws -> PipelineResult
}

enum GitLabError: Error {
    case unauthorized
    case notFound
    case networkError(Error)
    case invalidResponse
}
```

- [ ] **Step 3: 写失败测试**

```swift
// GitLabMonitorTests/GitLabServiceTests.swift
import XCTest
@testable import GitLabMonitor

final class GitLabServiceTests: XCTestCase {

    // Mock HTTP client
    struct MockHTTPClient: GitLabServiceProtocol {
        let responseData: Data
        let statusCode: Int

        func fetchLatestPipeline(
            gitlabUrl: String,
            projectPath: String,
            branch: String,
            token: String
        ) async throws -> PipelineResult {
            if statusCode == 401 { throw GitLabError.unauthorized }
            if statusCode == 404 { throw GitLabError.notFound }

            let json = try JSONDecoder().decode([PipelineJSON].self, from: responseData)
            guard let first = json.first else { throw GitLabError.invalidResponse }
            return PipelineResult(
                status: PipelineStatus(rawValue: first.status) ?? .unknown,
                webUrl: first.web_url,
                updatedAt: ISO8601DateFormatter().date(from: first.updated_at) ?? Date()
            )
        }
    }

    struct PipelineJSON: Decodable {
        let status: String
        let web_url: String
        let updated_at: String
    }

    func testParseSuccessPipeline() async throws {
        let json = """
        [{"status":"success","web_url":"https://gitlab.example.com/group/project/-/pipelines/1","updated_at":"2026-04-03T10:00:00Z"}]
        """.data(using: .utf8)!
        let mock = MockHTTPClient(responseData: json, statusCode: 200)
        let result = try await mock.fetchLatestPipeline(
            gitlabUrl: "https://gitlab.example.com",
            projectPath: "group/project",
            branch: "main",
            token: "test-token"
        )
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.webUrl, "https://gitlab.example.com/group/project/-/pipelines/1")
    }

    func testParseRunningPipeline() async throws {
        let json = """
        [{"status":"running","web_url":"https://gitlab.example.com/group/project/-/pipelines/2","updated_at":"2026-04-03T10:01:00Z"}]
        """.data(using: .utf8)!
        let mock = MockHTTPClient(responseData: json, statusCode: 200)
        let result = try await mock.fetchLatestPipeline(
            gitlabUrl: "https://gitlab.example.com",
            projectPath: "group/project",
            branch: "main",
            token: "test-token"
        )
        XCTAssertEqual(result.status, .running)
    }

    func testUnauthorizedThrows() async {
        let mock = MockHTTPClient(responseData: Data(), statusCode: 401)
        do {
            _ = try await mock.fetchLatestPipeline(
                gitlabUrl: "https://gitlab.example.com",
                projectPath: "group/project",
                branch: "main",
                token: "bad-token"
            )
            XCTFail("Expected GitLabError.unauthorized")
        } catch GitLabError.unauthorized {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNotFoundThrows() async {
        let mock = MockHTTPClient(responseData: Data(), statusCode: 404)
        do {
            _ = try await mock.fetchLatestPipeline(
                gitlabUrl: "https://gitlab.example.com",
                projectPath: "group/project",
                branch: "main",
                token: "test-token"
            )
            XCTFail("Expected GitLabError.notFound")
        } catch GitLabError.notFound {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
```

- [ ] **Step 4: 运行测试确认失败**

Command+U，预期：编译错误（`GitLabService` 尚未实现）

- [ ] **Step 5: 创建 GitLabService.swift**

```swift
import Foundation

struct GitLabService: GitLabServiceProtocol {

    private struct PipelineJSON: Decodable {
        let status: String
        let web_url: String
        let updated_at: String
    }

    func fetchLatestPipeline(
        gitlabUrl: String,
        projectPath: String,
        branch: String,
        token: String
    ) async throws -> PipelineResult {
        let encodedPath = projectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectPath
        let urlString = "\(gitlabUrl)/api/v4/projects/\(encodedPath)/pipelines?ref=\(branch)&per_page=1&order_by=id&sort=desc"
        guard let url = URL(string: urlString) else { throw GitLabError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GitLabError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw GitLabError.invalidResponse }
        if http.statusCode == 401 { throw GitLabError.unauthorized }
        if http.statusCode == 404 { throw GitLabError.notFound }

        let pipelines = try JSONDecoder().decode([PipelineJSON].self, from: data)
        guard let first = pipelines.first else { throw GitLabError.invalidResponse }

        let formatter = ISO8601DateFormatter()
        let updatedAt = formatter.date(from: first.updated_at) ?? Date()

        return PipelineResult(
            status: PipelineStatus(rawValue: first.status) ?? .unknown,
            webUrl: first.web_url,
            updatedAt: updatedAt
        )
    }
}
```

- [ ] **Step 6: 运行测试确认通过**

Command+U，预期：全部 PASS

- [ ] **Step 7: 提交**

```bash
git add GitLabMonitor/Services/ GitLabMonitorTests/
git commit -m "feat: add GitLabService with protocol abstraction and tests"
```

---

## Task 5: RepositoryStore

**Files:**
- Create: `GitLabMonitor/Store/RepositoryStore.swift`

- [ ] **Step 1: 创建 RepositoryStore.swift**

```swift
import Foundation
import SwiftUI

struct RepositoryState: Identifiable {
    let repository: Repository
    var status: PipelineStatus
    var webUrl: String?
    var updatedAt: Date?
    var errorMessage: String?

    var id: UUID { repository.id }
}

@MainActor
class RepositoryStore: ObservableObject {
    @Published var states: [RepositoryState] = []
    @Published var settings: AppSettings = .load()
    @Published var globalError: String? = nil

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        settings.save()
        syncStates()
    }

    func applyResult(_ result: PipelineResult, for repositoryId: UUID) {
        guard let index = states.firstIndex(where: { $0.id == repositoryId }) else { return }
        states[index].status = result.status
        states[index].webUrl = result.webUrl
        states[index].updatedAt = result.updatedAt
        states[index].errorMessage = nil
        globalError = nil
    }

    func applyError(_ error: GitLabError, for repositoryId: UUID) {
        guard let index = states.firstIndex(where: { $0.id == repositoryId }) else { return }
        states[index].status = .unknown
        states[index].errorMessage = errorMessage(for: error)
        if case .unauthorized = error {
            globalError = "Token 无效，请检查设置"
        }
    }

    var overallStatus: PipelineStatus {
        if states.isEmpty { return .unknown }
        if states.contains(where: { $0.status == .failed }) { return .failed }
        if states.contains(where: { $0.status == .running || $0.status == .pending }) { return .running }
        if states.allSatisfy({ $0.status == .success }) { return .success }
        return .unknown
    }

    private func syncStates() {
        let existing = Dictionary(uniqueKeysWithValues: states.map { ($0.id, $0) })
        states = settings.repositories.map { repo in
            existing[repo.id] ?? RepositoryState(repository: repo, status: .unknown)
        }
    }

    private func errorMessage(for error: GitLabError) -> String {
        switch error {
        case .unauthorized: return "Token 无效"
        case .notFound: return "项目未找到"
        case .networkError: return "连接失败"
        case .invalidResponse: return "响应异常"
        }
    }
}
```

- [ ] **Step 2: 构建验证**

Command+B，确认无编译错误。

- [ ] **Step 3: 提交**

```bash
git add GitLabMonitor/Store/RepositoryStore.swift
git commit -m "feat: add RepositoryStore observable state management"
```

---

## Task 6: PipelinePoller（含测试）

**Files:**
- Create: `GitLabMonitor/Polling/PipelinePoller.swift`
- Create: `GitLabMonitorTests/PipelinePollerTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// GitLabMonitorTests/PipelinePollerTests.swift
import XCTest
@testable import GitLabMonitor

@MainActor
final class PipelinePollerTests: XCTestCase {

    struct MockGitLabService: GitLabServiceProtocol {
        var result: Result<PipelineResult, GitLabError>

        func fetchLatestPipeline(
            gitlabUrl: String,
            projectPath: String,
            branch: String,
            token: String
        ) async throws -> PipelineResult {
            switch result {
            case .success(let r): return r
            case .failure(let e): throw e
            }
        }
    }

    func testPollerUpdatesStoreOnSuccess() async throws {
        let store = RepositoryStore()
        let repo = Repository(name: "test", projectPath: "group/project", branch: "main")
        var settings = AppSettings.default
        settings.gitlabUrl = "https://gitlab.example.com"
        settings.repositories = [repo]
        store.updateSettings(settings)

        let mockResult = PipelineResult(
            status: .success,
            webUrl: "https://gitlab.example.com/group/project/-/pipelines/1",
            updatedAt: Date()
        )
        let mockService = MockGitLabService(result: .success(mockResult))
        let poller = PipelinePoller(store: store, service: mockService)

        await poller.pollOnce(token: "test-token")

        XCTAssertEqual(store.states.first?.status, .success)
        XCTAssertNil(store.states.first?.errorMessage)
    }

    func testPollerUpdatesStoreOnError() async throws {
        let store = RepositoryStore()
        let repo = Repository(name: "test", projectPath: "group/project", branch: "main")
        var settings = AppSettings.default
        settings.gitlabUrl = "https://gitlab.example.com"
        settings.repositories = [repo]
        store.updateSettings(settings)

        let mockService = MockGitLabService(result: .failure(.notFound))
        let poller = PipelinePoller(store: store, service: mockService)

        await poller.pollOnce(token: "test-token")

        XCTAssertEqual(store.states.first?.status, .unknown)
        XCTAssertEqual(store.states.first?.errorMessage, "项目未找到")
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Command+U，预期编译错误（PipelinePoller 未实现）

- [ ] **Step 3: 创建 PipelinePoller.swift**

```swift
import Foundation

@MainActor
class PipelinePoller {
    private let store: RepositoryStore
    private let service: GitLabServiceProtocol
    private var timer: Timer?

    init(store: RepositoryStore, service: GitLabServiceProtocol = GitLabService()) {
        self.store = store
        self.service = service
    }

    func start() {
        stopTimer()
        let interval = TimeInterval(store.settings.pollInterval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollOnce(token: KeychainService.loadToken() ?? "")
            }
        }
        // 立即执行一次
        Task { @MainActor in
            await pollOnce(token: KeychainService.loadToken() ?? "")
        }
    }

    func stop() {
        stopTimer()
    }

    func pollOnce(token: String) async {
        let settings = store.settings
        await withTaskGroup(of: Void.self) { group in
            for repo in settings.repositories {
                group.addTask { @MainActor in
                    do {
                        let result = try await self.service.fetchLatestPipeline(
                            gitlabUrl: settings.gitlabUrl,
                            projectPath: repo.projectPath,
                            branch: repo.branch,
                            token: token
                        )
                        self.store.applyResult(result, for: repo.id)
                    } catch let error as GitLabError {
                        self.store.applyError(error, for: repo.id)
                    } catch {
                        self.store.applyError(.networkError(error), for: repo.id)
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Command+U，预期全部 PASS

- [ ] **Step 5: 提交**

```bash
git add GitLabMonitor/Polling/ GitLabMonitorTests/PipelinePollerTests.swift
git commit -m "feat: add PipelinePoller with async polling and tests"
```

---

## Task 7: AppDelegate + 菜单栏图标

**Files:**
- Create: `GitLabMonitor/AppDelegate.swift`

- [ ] **Step 1: 创建 AppDelegate.swift**

```swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var store: RepositoryStore!
    private var poller: PipelinePoller!

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = RepositoryStore()
        poller = PipelinePoller(store: store)

        setupStatusItem()
        setupPopover()

        poller.start()

        // 监听状态变化更新图标颜色
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

    @objc private func updateIcon() {
        let status = store.overallStatus
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        statusItem.button?.image = image
        statusItem.button?.contentTintColor = NSColor(status.color)
    }
}

extension Notification.Name {
    static let repositoryStateDidChange = Notification.Name("repositoryStateDidChange")
}
```

- [ ] **Step 2: 在 RepositoryStore 中发送通知**

在 `RepositoryStore.swift` 的 `applyResult` 和 `applyError` 方法末尾各添加：
```swift
NotificationCenter.default.post(name: .repositoryStateDidChange, object: nil)
```

- [ ] **Step 3: 构建并手动测试**

Command+R 运行，菜单栏应出现灰色圆点图标，点击无崩溃。

- [ ] **Step 4: 提交**

```bash
git add GitLabMonitor/AppDelegate.swift GitLabMonitor/Store/RepositoryStore.swift
git commit -m "feat: add AppDelegate with NSStatusItem and popover setup"
```

---

## Task 8: MonitorView（监控面板 UI）

**Files:**
- Create: `GitLabMonitor/Views/RepositoryRowView.swift`
- Create: `GitLabMonitor/Views/MonitorView.swift`

- [ ] **Step 1: 创建 RepositoryRowView.swift**

```swift
import SwiftUI

struct RepositoryRowView: View {
    let state: RepositoryState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Circle()
                    .fill(state.status.color)
                    .frame(width: 10, height: 10)
                Text(state.repository.name)
                    .fontWeight(.medium)
                Spacer()
                Text(state.repository.branch)
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(state.status.symbol + " " + state.status.label)
                    .font(.caption)
                    .foregroundColor(state.status.color)
            }
            HStack {
                if let errorMessage = state.errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.red)
                } else if let updatedAt = state.updatedAt {
                    Text(updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let webUrl = state.webUrl, let url = URL(string: webUrl) {
                    Link("↗", destination: url)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 2: 创建 MonitorView.swift**

```swift
import SwiftUI

struct MonitorView: View {
    @ObservedObject var store: RepositoryStore
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("GitLab Monitor")
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // 全局错误提示
            if let error = store.globalError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                Divider()
            }

            // 仓库列表
            if store.states.isEmpty {
                Text("暂无仓库，请在设置中添加")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.states) { state in
                            RepositoryRowView(state: state)
                                .padding(.horizontal, 12)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(width: 320)
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
        }
    }
}
```

- [ ] **Step 3: 构建并手动测试**

Command+R，点击菜单栏图标，面板弹出，显示"暂无仓库，请在设置中添加"。

- [ ] **Step 4: 提交**

```bash
git add GitLabMonitor/Views/
git commit -m "feat: add MonitorView and RepositoryRowView"
```

---

## Task 9: SettingsView（设置页 UI）

**Files:**
- Create: `GitLabMonitor/Views/SettingsView.swift`

- [ ] **Step 1: 创建 SettingsView.swift**

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: RepositoryStore
    @Environment(\.dismiss) var dismiss

    @State private var gitlabUrl: String = ""
    @State private var token: String = ""
    @State private var pollInterval: String = "60"
    @State private var showAddRepo = false
    @State private var editingRepo: Repository? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("设置")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("完成") { saveAndDismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            Form {
                Section {
                    TextField("https://gitlab.company.com", text: $gitlabUrl)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("GitLab 地址")
                }

                Section {
                    SecureField("glpat-xxxxxxxxxxxxxxxxxxxx", text: $token)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Text("需要 read_api 权限")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("?") {
                            let baseUrl = gitlabUrl.isEmpty ? "https://gitlab.com" : gitlabUrl
                            if let url = URL(string: "\(baseUrl)/-/user_settings/personal_access_tokens") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                } header: {
                    Text("Access Token")
                }

                Section {
                    HStack {
                        TextField("60", text: $pollInterval)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("秒")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("轮询间隔")
                }

                Section {
                    ForEach(store.settings.repositories) { repo in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(repo.name).fontWeight(.medium)
                                Text("\(repo.projectPath) @ \(repo.branch)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("编辑") { editingRepo = repo }
                                .buttonStyle(.plain)
                                .foregroundColor(.accentColor)
                            Button("删除") { deleteRepo(repo) }
                                .buttonStyle(.plain)
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 2)
                    }
                    Button("+ 添加仓库") { showAddRepo = true }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                } header: {
                    Text("仓库列表")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 420, height: 520)
        .onAppear { loadCurrentSettings() }
        .sheet(isPresented: $showAddRepo) {
            RepoFormView(existingRepo: nil) { newRepo in
                var settings = store.settings
                settings.repositories.append(newRepo)
                store.updateSettings(settings)
            }
        }
        .sheet(item: $editingRepo) { repo in
            RepoFormView(existingRepo: repo) { updated in
                var settings = store.settings
                if let idx = settings.repositories.firstIndex(where: { $0.id == updated.id }) {
                    settings.repositories[idx] = updated
                }
                store.updateSettings(settings)
            }
        }
    }

    private func loadCurrentSettings() {
        gitlabUrl = store.settings.gitlabUrl
        token = KeychainService.loadToken() ?? ""
        pollInterval = "\(store.settings.pollInterval)"
    }

    private func saveAndDismiss() {
        var settings = store.settings
        settings.gitlabUrl = gitlabUrl
        settings.pollInterval = Int(pollInterval) ?? 60
        store.updateSettings(settings)
        KeychainService.saveToken(token)
        dismiss()
    }

    private func deleteRepo(_ repo: Repository) {
        var settings = store.settings
        settings.repositories.removeAll { $0.id == repo.id }
        store.updateSettings(settings)
    }
}

struct RepoFormView: View {
    let existingRepo: Repository?
    let onSave: (Repository) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var projectPath: String = ""
    @State private var branch: String = "main"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(existingRepo == nil ? "添加仓库" : "编辑仓库")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button("取消") { dismiss() }.buttonStyle(.plain)
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || projectPath.isEmpty || branch.isEmpty)
            }
            .padding()
            Divider()
            Form {
                TextField("前端服务", text: $name)
                    .textFieldStyle(.roundedBorder)
                    TextField("group/project", text: $projectPath)
                    .textFieldStyle(.roundedBorder)
                    TextField("main", text: $branch)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)
        }
        .frame(width: 360, height: 280)
        .onAppear {
            if let repo = existingRepo {
                name = repo.name
                projectPath = repo.projectPath
                branch = repo.branch
            }
        }
    }

    private func save() {
        let repo = Repository(
            id: existingRepo?.id ?? UUID(),
            name: name,
            projectPath: projectPath,
            branch: branch
        )
        onSave(repo)
        dismiss()
    }
}
```

- [ ] **Step 2: 构建并手动测试**

Command+R，点击面板齿轮图标，设置页弹出：
- 填写 GitLab URL 和 Token，点击 `?` 应跳转到浏览器
- 添加一个测试仓库，确认出现在列表中
- 点击完成，仓库行应出现在监控面板

- [ ] **Step 3: 提交**

```bash
git add GitLabMonitor/Views/SettingsView.swift
git commit -m "feat: add SettingsView with repo management and token help link"
```

---

## Task 10: 轮询重启 + 收尾

**Files:**
- Modify: `GitLabMonitor/AppDelegate.swift`
- Modify: `GitLabMonitor/Polling/PipelinePoller.swift`

- [ ] **Step 1: 设置变更时重启轮询**

在 `AppDelegate.swift` 的 `applicationDidFinishLaunching` 中添加对设置变更的观察：

```swift
// 在 setupStatusItem() 后添加
store.objectWillChange.sink { [weak self] in
    DispatchQueue.main.async {
        self?.poller.stop()
        self?.poller.start()
        self?.updateIcon()
    }
}.store(in: &cancellables)
```

在 `AppDelegate` 类中添加：
```swift
import Combine
private var cancellables = Set<AnyCancellable>()
```

- [ ] **Step 2: 构建并端到端测试**

Command+R，完整流程测试：
1. 打开设置，填入真实 GitLab URL、Token、仓库路径和 branch
2. 点击完成，面板内应出现仓库行
3. 等待轮询（默认 60 秒，可临时改为 5 秒测试）
4. 状态圆点和菜单栏图标颜色应随 pipeline 状态更新
5. 点击 `↗` 跳转浏览器验证

- [ ] **Step 3: 最终提交**

```bash
git add .
git commit -m "feat: restart poller on settings change, complete implementation"
```

---

## 自检：Spec 覆盖确认

| Spec 需求 | 任务覆盖 |
|-----------|---------|
| 菜单栏图标颜色反映最严重状态 | Task 7 (AppDelegate.updateIcon + RepositoryStore.overallStatus) |
| 动态添加/删除仓库 | Task 9 (SettingsView, RepoFormView) |
| 每个仓库可指定 branch | Task 2 (Repository.branch), Task 9 (RepoFormView) |
| 显示仓库名、branch、状态、时间 | Task 8 (RepositoryRowView) |
| 点击跳转 GitLab Pipeline 页面 | Task 8 (RepositoryRowView Link) |
| 设置页可配置 GitLab URL、Token | Task 9 (SettingsView) |
| Token 存 Keychain | Task 3 (KeychainService) |
| 轮询间隔可 UI 配置 | Task 9 (SettingsView pollInterval) |
| Token 帮助链接 + read_api 提示 | Task 9 (SettingsView ? button) |
| 错误处理（401/404/网络） | Task 4 (GitLabService), Task 5 (RepositoryStore) |
| 无 Dock 图标 | Task 1 (LSUIElement) |

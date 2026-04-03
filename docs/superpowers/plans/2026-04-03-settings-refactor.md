# Settings Refactor + UX Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构设置页为两步向导并接入 GitLab API 仓库搜索，同时修复菜单栏图标、popover 关闭、右键退出等 UX 问题。

**Architecture:** 新增 `GitLabProject`/`GitLabBranch` 模型和对应 API 方法；`SettingsView` 改为两步向导，第二步用 `ProjectSearchView` 展示 API 搜索结果并支持多选；`AppDelegate` 增加全局鼠标事件监听修复 popover 关闭，以及右键菜单支持退出。

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, GitLab API v4 (compatible with CE 14.10+)

---

## 文件结构

```
GitLabMonitor/
├── Assets.xcassets/
│   └── gitlab-icon.imageset/      (新增) GitLab logo 单色图标
├── Models/
│   ├── GitLabProject.swift        (新增) GitLab 项目模型
│   └── GitLabBranch.swift         (新增) GitLab branch 模型
├── Services/
│   ├── GitLabServiceProtocol.swift (修改) 新增 fetchProjects/fetchBranches
│   └── GitLabService.swift         (修改) 实现新方法
├── Views/
│   ├── SettingsView.swift          (重写) 两步向导
│   └── ProjectSearchView.swift     (新增) 仓库多选搜索视图
└── AppDelegate.swift               (修改) popover 关闭 + 右键退出
```

---

## Task 1: 菜单栏图标 + popover 关闭 + 右键退出

**Files:**
- Modify: `GitLabMonitor/AppDelegate.swift`
- Create: `GitLabMonitor/Assets.xcassets/gitlab-icon.imageset/Contents.json`
- Create: `GitLabMonitor/Assets.xcassets/gitlab-icon.imageset/gitlab-icon.pdf`
- Modify: `project.yml`

- [ ] **Step 1: 创建 Assets.xcassets 目录和 GitLab 图标**

```bash
cd /Users/norman/development/gitlab-monitor
mkdir -p GitLabMonitor/Assets.xcassets/AppIcon.appiconset
mkdir -p GitLabMonitor/Assets.xcassets/gitlab-icon.imageset

cat > GitLabMonitor/Assets.xcassets/Contents.json << 'JSONEOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSONEOF

cat > GitLabMonitor/Assets.xcassets/gitlab-icon.imageset/Contents.json << 'JSONEOF'
{
  "images" : [
    {
      "filename" : "gitlab-icon.svg",
      "idiom" : "universal",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}
JSONEOF
```

- [ ] **Step 2: 创建 GitLab fox logo SVG（单色模板图）**

```bash
cat > GitLabMonitor/Assets.xcassets/gitlab-icon.imageset/gitlab-icon.svg << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18" width="18" height="18">
  <path fill="#000000" d="M9 16.5l-3.26-10.03L2.5 16.5H9zm0 0l3.26-10.03L15.5 16.5H9zM2.5 16.5L.5 10.5l3.26 4.5L2.5 16.5zm13 0l2-6-3.26 4.5 1.26 1.5zM3.76 6.47L2.5 10.5l1.5-2.25.76-1.78zm10.48 0L15.5 10.5l-1.5-2.25-.76-1.78zM9 1.5L6.5 6.47h5L9 1.5z"/>
</svg>
SVGEOF
```

- [ ] **Step 3: 在 project.yml 中添加 Assets.xcassets**

读取当前 `project.yml`，在 `sources:` 下添加 assets：

```bash
cd /Users/norman/development/gitlab-monitor
# 在 sources 列表（GitLabMonitor 目录下）之后检查是否有 resources 配置
grep -n "resources\|sources\|assets" project.yml | head -20
```

如果 project.yml 中没有 `resources` 字段，在 `GitLabMonitor` target 的 `sources` 下面添加：
```yaml
    resources:
      - GitLabMonitor/Assets.xcassets
```

- [ ] **Step 4: 修改 AppDelegate.swift — 图标 + popover 关闭 + 右键退出**

完整替换 `GitLabMonitor/AppDelegate.swift`：

```swift
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

        // 左键显示 popover，右键显示退出菜单
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
        // 全局鼠标监听：点击 popover 外部时关闭
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
                // fallback
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                let fallback = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
                    .withSymbolConfiguration(config)
                self.statusItem.button?.image = fallback
            }
            self.statusItem.button?.contentTintColor = NSColor(status.color)
        }
    }
}
```

- [ ] **Step 5: 重新生成项目并构建**

```bash
cd /Users/norman/development/gitlab-monitor
xcodegen generate
xcodebuild -project GitLabMonitor.xcodeproj -scheme GitLabMonitor -destination 'platform=macOS' build 2>&1 | tail -5
```

期望：`** BUILD SUCCEEDED **`

- [ ] **Step 6: 提交**

```bash
cd /Users/norman/development/gitlab-monitor
git add GitLabMonitor/Assets.xcassets/ GitLabMonitor/AppDelegate.swift project.yml
git commit -m "feat: add GitLab icon, fix popover close, add right-click quit"
```

---

## Task 2: GitLabProject + GitLabBranch 模型 + API 方法（含测试）

**Files:**
- Create: `GitLabMonitor/Models/GitLabProject.swift`
- Create: `GitLabMonitor/Models/GitLabBranch.swift`
- Modify: `GitLabMonitor/Services/GitLabServiceProtocol.swift`
- Modify: `GitLabMonitor/Services/GitLabService.swift`
- Create: `GitLabMonitorTests/GitLabProjectFetchTests.swift`

- [ ] **Step 1: 创建 GitLabProject.swift**

```swift
// GitLabMonitor/Models/GitLabProject.swift
import Foundation

struct GitLabProject: Identifiable, Decodable {
    let id: Int
    let name: String
    let pathWithNamespace: String
    let defaultBranch: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case pathWithNamespace = "path_with_namespace"
        case defaultBranch = "default_branch"
    }
}
```

- [ ] **Step 2: 创建 GitLabBranch.swift**

```swift
// GitLabMonitor/Models/GitLabBranch.swift
import Foundation

struct GitLabBranch: Decodable {
    let name: String
}
```

- [ ] **Step 3: 写失败测试**

创建 `GitLabMonitorTests/GitLabProjectFetchTests.swift`：

```swift
import XCTest
@testable import GitLabMonitor

final class GitLabProjectFetchTests: XCTestCase {

    struct MockFetchService: GitLabServiceProtocol {
        var projectsResult: Result<[GitLabProject], GitLabError>
        var branchesResult: Result<[GitLabBranch], GitLabError>

        func fetchLatestPipeline(gitlabUrl: String, projectPath: String, branch: String, token: String) async throws -> PipelineResult {
            throw GitLabError.invalidResponse
        }

        func fetchProjects(gitlabUrl: String, token: String, search: String) async throws -> [GitLabProject] {
            switch projectsResult {
            case .success(let p): return p
            case .failure(let e): throw e
            }
        }

        func fetchBranches(gitlabUrl: String, token: String, projectId: Int) async throws -> [GitLabBranch] {
            switch branchesResult {
            case .success(let b): return b
            case .failure(let e): throw e
            }
        }
    }

    func testFetchProjectsReturnsProjects() async throws {
        let projects = [
            GitLabProject(id: 1, name: "frontend", pathWithNamespace: "group/frontend", defaultBranch: "main"),
            GitLabProject(id: 2, name: "backend", pathWithNamespace: "group/backend", defaultBranch: "develop")
        ]
        let mock = MockFetchService(projectsResult: .success(projects), branchesResult: .success([]))
        let result = try await mock.fetchProjects(gitlabUrl: "https://gitlab.example.com", token: "token", search: "")
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].pathWithNamespace, "group/frontend")
        XCTAssertEqual(result[0].defaultBranch, "main")
    }

    func testFetchBranchesReturnsBranches() async throws {
        let branches = [GitLabBranch(name: "main"), GitLabBranch(name: "develop")]
        let mock = MockFetchService(projectsResult: .success([]), branchesResult: .success(branches))
        let result = try await mock.fetchBranches(gitlabUrl: "https://gitlab.example.com", token: "token", projectId: 1)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "main")
    }

    func testFetchProjectsUnauthorizedThrows() async {
        let mock = MockFetchService(projectsResult: .failure(.unauthorized), branchesResult: .success([]))
        do {
            _ = try await mock.fetchProjects(gitlabUrl: "https://gitlab.example.com", token: "bad", search: "")
            XCTFail("Expected unauthorized")
        } catch GitLabError.unauthorized {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
```

- [ ] **Step 4: 运行测试确认失败（编译错误，方法未实现）**

```bash
cd /Users/norman/development/gitlab-monitor
xcodegen generate
xcodebuild test -project GitLabMonitor.xcodeproj -scheme GitLabMonitor -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "error:|BUILD" | head -10
```

期望：编译错误（`fetchProjects` 不存在）

- [ ] **Step 5: 更新 GitLabServiceProtocol.swift**

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

    func fetchProjects(
        gitlabUrl: String,
        token: String,
        search: String
    ) async throws -> [GitLabProject]

    func fetchBranches(
        gitlabUrl: String,
        token: String,
        projectId: Int
    ) async throws -> [GitLabBranch]
}

enum GitLabError: Error {
    case unauthorized
    case notFound
    case networkError(Error)
    case invalidResponse
}
```

- [ ] **Step 6: 更新 GitLabService.swift 实现新方法**

完整替换文件内容：

```swift
import Foundation

struct GitLabService: GitLabServiceProtocol {

    // MARK: - Pipeline

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
        let encodedBranch = branch.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? branch
        let urlString = "\(gitlabUrl)/api/v4/projects/\(encodedPath)/pipelines?ref=\(encodedBranch)&per_page=1&order_by=id&sort=desc"
        let data = try await get(urlString: urlString, token: token)
        let pipelines = try JSONDecoder().decode([PipelineJSON].self, from: data)
        guard let first = pipelines.first else { throw GitLabError.invalidResponse }
        let updatedAt = ISO8601DateFormatter().date(from: first.updated_at) ?? Date()
        return PipelineResult(
            status: PipelineStatus(rawValue: first.status) ?? .unknown,
            webUrl: first.web_url,
            updatedAt: updatedAt
        )
    }

    // MARK: - Projects

    func fetchProjects(gitlabUrl: String, token: String, search: String) async throws -> [GitLabProject] {
        let encodedSearch = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
        let urlString = "\(gitlabUrl)/api/v4/projects?membership=true&order_by=last_activity_at&sort=desc&per_page=5&search=\(encodedSearch)"
        let data = try await get(urlString: urlString, token: token)
        return try JSONDecoder().decode([GitLabProject].self, from: data)
    }

    // MARK: - Branches

    func fetchBranches(gitlabUrl: String, token: String, projectId: Int) async throws -> [GitLabBranch] {
        let urlString = "\(gitlabUrl)/api/v4/projects/\(projectId)/branches?per_page=50&order_by=updated_at"
        let data = try await get(urlString: urlString, token: token)
        return try JSONDecoder().decode([GitLabBranch].self, from: data)
    }

    // MARK: - Shared HTTP

    private func get(urlString: String, token: String) async throws -> Data {
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
        return data
    }
}
```

- [ ] **Step 7: 运行所有测试确认通过**

```bash
cd /Users/norman/development/gitlab-monitor
xcodegen generate
xcodebuild test -project GitLabMonitor.xcodeproj -scheme GitLabMonitor -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "PASS|FAIL|BUILD|Test Suite" | tail -15
```

期望：全部 PASS（原 6 条 + 新 3 条 = 9 条）

- [ ] **Step 8: 提交**

```bash
cd /Users/norman/development/gitlab-monitor
git add GitLabMonitor/Models/GitLabProject.swift GitLabMonitor/Models/GitLabBranch.swift \
        GitLabMonitor/Services/GitLabServiceProtocol.swift GitLabMonitor/Services/GitLabService.swift \
        GitLabMonitorTests/GitLabProjectFetchTests.swift
git commit -m "feat: add GitLabProject/Branch models and fetchProjects/fetchBranches API methods"
```

---

## Task 3: ProjectSearchView（仓库多选搜索）

**Files:**
- Create: `GitLabMonitor/Views/ProjectSearchView.swift`

- [ ] **Step 1: 创建 ProjectSearchView.swift**

```swift
// GitLabMonitor/Views/ProjectSearchView.swift
import SwiftUI

/// 一条已选仓库的草稿（尚未保存到 store）
struct SelectedProject: Identifiable {
    let id: Int              // GitLabProject.id
    let pathWithNamespace: String
    var branch: String
    var availableBranches: [String] = []
    var loadingBranches: Bool = false
    var branchLoadError: Bool = false
}

struct ProjectSearchView: View {
    let gitlabUrl: String
    let token: String
    let service: GitLabServiceProtocol
    /// 已在 store 中的仓库路径，避免重复添加
    let existingPaths: Set<String>
    let onAdd: ([Repository]) -> Void

    @State private var searchText: String = ""
    @State private var searchResults: [GitLabProject] = []
    @State private var isLoading: Bool = false
    @State private var loadError: String? = nil
    @State private var selected: [SelectedProject] = []
    @State private var searchTask: Task<Void, Never>? = nil
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("添加仓库")
                    .font(.title3).fontWeight(.semibold)
                Spacer()
                if !selected.isEmpty {
                    Text("已选 \(selected.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()

            Divider()

            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索仓库名称...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _ in scheduleSearch() }
                if isLoading {
                    ProgressView().scaleEffect(0.6)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    // 已选区域（搜索时不消失）
                    let unlistedSelected = selected.filter { s in
                        !searchResults.contains { $0.id == s.id }
                    }
                    if !unlistedSelected.isEmpty {
                        sectionHeader("已选择")
                        ForEach(unlistedSelected) { s in
                            selectedRow(s)
                            Divider().padding(.leading, 32)
                        }
                    }

                    // 搜索结果
                    if let error = loadError {
                        errorView(error)
                    } else if searchResults.isEmpty && !isLoading {
                        emptyView()
                    } else {
                        if !searchResults.isEmpty {
                            sectionHeader(searchText.isEmpty ? "最近更新" : "搜索结果")
                        }
                        ForEach(searchResults) { project in
                            projectRow(project)
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }

            Divider()

            // 底部按钮
            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(.plain)
                Spacer()
                Button("添加 \(selected.count > 0 ? "\(selected.count) 个" : "")") {
                    commitSelection()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 480)
        .onAppear { scheduleSearch() }
    }

    // MARK: - Row Views

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    @ViewBuilder
    private func projectRow(_ project: GitLabProject) -> some View {
        let isSelected = selected.contains { $0.id == project.id }
        HStack {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name).fontWeight(.medium)
                Text(project.pathWithNamespace)
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleSelection(project) }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)

        // branch 下拉（仅选中时显示）
        if let idx = selected.firstIndex(where: { $0.id == project.id }) {
            branchPicker(idx: idx)
                .padding(.leading, 44)
                .padding(.trailing, 12)
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func selectedRow(_ s: SelectedProject) -> some View {
        HStack {
            Image(systemName: "checkmark.square.fill")
                .foregroundColor(.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(s.pathWithNamespace.components(separatedBy: "/").last ?? s.pathWithNamespace)
                    .fontWeight(.medium)
                Text(s.pathWithNamespace)
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "xmark.circle")
                .foregroundColor(.secondary)
                .onTapGesture {
                    selected.removeAll { $0.id == s.id }
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)

        if let idx = selected.firstIndex(where: { $0.id == s.id }) {
            branchPicker(idx: idx)
                .padding(.leading, 44)
                .padding(.trailing, 12)
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func branchPicker(idx: Int) -> some View {
        if selected[idx].loadingBranches {
            HStack {
                ProgressView().scaleEffect(0.6)
                Text("加载 branch...").font(.caption).foregroundColor(.secondary)
            }
        } else if selected[idx].branchLoadError {
            HStack {
                Text("加载失败，手动输入：").font(.caption).foregroundColor(.red)
                TextField("branch", text: $selected[idx].branch)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .frame(width: 120)
            }
        } else if selected[idx].availableBranches.isEmpty {
            // branches 尚未加载
            EmptyView()
        } else {
            HStack {
                Text("Branch:").font(.caption).foregroundColor(.secondary)
                Picker("", selection: $selected[idx].branch) {
                    ForEach(selected[idx].availableBranches, id: \.self) { b in
                        Text(b).tag(b)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 180)
            }
        }
    }

    @ViewBuilder
    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Text(msg).font(.caption).foregroundColor(.red)
            Button("重试") { scheduleSearch() }
                .font(.caption)
        }
        .padding()
    }

    @ViewBuilder
    private func emptyView() -> some View {
        Text(searchText.isEmpty ? "暂无可用仓库" : "未找到相关仓库")
            .font(.caption).foregroundColor(.secondary)
            .padding()
    }

    // MARK: - Logic

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            if !searchText.isEmpty {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            }
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    @MainActor
    private func performSearch() async {
        isLoading = true
        loadError = nil
        do {
            searchResults = try await service.fetchProjects(
                gitlabUrl: gitlabUrl,
                token: token,
                search: searchText
            )
        } catch {
            loadError = "加载失败，请检查连接设置"
        }
        isLoading = false
    }

    private func toggleSelection(_ project: GitLabProject) {
        if let idx = selected.firstIndex(where: { $0.id == project.id }) {
            selected.remove(at: idx)
        } else {
            let defaultBranch = project.defaultBranch ?? "main"
            var s = SelectedProject(
                id: project.id,
                pathWithNamespace: project.pathWithNamespace,
                branch: defaultBranch
            )
            s.loadingBranches = true
            selected.append(s)
            loadBranches(for: project)
        }
    }

    private func loadBranches(for project: GitLabProject) {
        Task { @MainActor in
            guard let idx = selected.firstIndex(where: { $0.id == project.id }) else { return }
            do {
                let branches = try await service.fetchBranches(
                    gitlabUrl: gitlabUrl,
                    token: token,
                    projectId: project.id
                )
                guard let i = selected.firstIndex(where: { $0.id == project.id }) else { return }
                selected[i].availableBranches = branches.map(\.name)
                selected[i].loadingBranches = false
                // 保持默认 branch 选中（如果存在于列表中）
                if !selected[i].availableBranches.contains(selected[i].branch),
                   let first = selected[i].availableBranches.first {
                    selected[i].branch = first
                }
            } catch {
                guard let i = selected.firstIndex(where: { $0.id == project.id }) else { return }
                selected[i].loadingBranches = false
                selected[i].branchLoadError = true
            }
        }
    }

    private func commitSelection() {
        let repos = selected.compactMap { s -> Repository? in
            guard !existingPaths.contains(s.pathWithNamespace) else { return nil }
            let name = s.pathWithNamespace.components(separatedBy: "/").last ?? s.pathWithNamespace
            return Repository(name: name, projectPath: s.pathWithNamespace, branch: s.branch)
        }
        onAdd(repos)
        dismiss()
    }
}
```

- [ ] **Step 2: 构建验证**

```bash
cd /Users/norman/development/gitlab-monitor
xcodegen generate
xcodebuild -project GitLabMonitor.xcodeproj -scheme GitLabMonitor -destination 'platform=macOS' build 2>&1 | tail -5
```

期望：`** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交**

```bash
cd /Users/norman/development/gitlab-monitor
git add GitLabMonitor/Views/ProjectSearchView.swift
git commit -m "feat: add ProjectSearchView with multi-select and branch picker"
```

---

## Task 4: SettingsView 两步向导 + Token URL 修正

**Files:**
- Modify: `GitLabMonitor/Views/SettingsView.swift`

- [ ] **Step 1: 完整替换 SettingsView.swift**

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: RepositoryStore
    @Environment(\.dismiss) var dismiss

    @State private var step: Int = 1
    @State private var gitlabUrl: String = ""
    @State private var token: String = ""
    @State private var pollInterval: String = "60"
    @State private var editingRepo: Repository? = nil
    @State private var showAddRepo: Bool = false

    private var canProceed: Bool {
        !gitlabUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
        !token.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if step == 1 {
                step1View
            } else {
                step2View
            }
        }
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { loadCurrentSettings() }
        .sheet(item: $editingRepo) { repo in
            RepoFormView(existingRepo: repo) { updated in
                var s = store.settings
                if let idx = s.repositories.firstIndex(where: { $0.id == updated.id }) {
                    s.repositories[idx] = updated
                }
                store.updateSettings(s)
            }
        }
        .sheet(isPresented: $showAddRepo) {
            ProjectSearchView(
                gitlabUrl: savedGitlabUrl,
                token: savedToken,
                service: GitLabService(),
                existingPaths: Set(store.settings.repositories.map(\.projectPath))
            ) { newRepos in
                var s = store.settings
                s.repositories.append(contentsOf: newRepos)
                store.updateSettings(s)
            }
        }
    }

    // MARK: - Step 1

    private var step1View: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("连接设置")
                    .font(.title2).fontWeight(.semibold)
                Spacer()
                Text("1 / 2")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding()
            Divider()
            Form {
                Section {
                    TextField("https://gitlab.company.com", text: $gitlabUrl)
                        .textFieldStyle(.roundedBorder)
                } header: { Text("GitLab 地址") }

                Section {
                    SecureField("glpat-xxxxxxxxxxxxxxxxxxxx", text: $token)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Text("需要 read_api 权限")
                            .font(.caption).foregroundColor(.secondary)
                        Button("?") {
                            let base = gitlabUrl.isEmpty ? "https://gitlab.com" : gitlabUrl
                            if let url = URL(string: "\(base)/-/profile/personal_access_tokens") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .font(.caption).buttonStyle(.plain).foregroundColor(.accentColor)
                    }
                } header: { Text("Access Token") }

                Section {
                    HStack {
                        TextField("60", text: $pollInterval)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("秒").foregroundColor(.secondary)
                    }
                } header: { Text("轮询间隔") }
            }
            .formStyle(.grouped)
            .frame(height: 320)

            Divider()
            HStack {
                Spacer()
                Button("下一步 →") {
                    saveConnectionSettings()
                    step = 2
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceed)
            }
            .padding()
        }
    }

    // MARK: - Step 2

    private var step2View: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("监控仓库")
                    .font(.title2).fontWeight(.semibold)
                Spacer()
                Text("2 / 2")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding()
            Divider()

            List {
                ForEach(store.settings.repositories) { repo in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(repo.name).fontWeight(.medium)
                            Text("\(repo.projectPath) @ \(repo.branch)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("编辑") { editingRepo = repo }
                            .buttonStyle(.plain).foregroundColor(.accentColor)
                        Button("删除") { deleteRepo(repo) }
                            .buttonStyle(.plain).foregroundColor(.red)
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(height: 220)

            Divider()
            HStack {
                Button("← 返回") { step = 1 }
                    .buttonStyle(.plain)
                Button("+ 添加仓库") { showAddRepo = true }
                    .buttonStyle(.plain).foregroundColor(.accentColor)
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    // MARK: - Helpers

    // 保存后的值，供 ProjectSearchView 使用
    private var savedGitlabUrl: String { store.settings.gitlabUrl }
    private var savedToken: String { KeychainService.loadToken() ?? "" }

    private func loadCurrentSettings() {
        gitlabUrl = store.settings.gitlabUrl
        token = KeychainService.loadToken() ?? ""
        pollInterval = "\(store.settings.pollInterval)"
        // 如果已有连接配置，直接跳到第二步
        if !gitlabUrl.isEmpty && !token.isEmpty {
            step = 2
        }
    }

    private func saveConnectionSettings() {
        var s = store.settings
        s.gitlabUrl = gitlabUrl.trimmingCharacters(in: .whitespaces)
        s.pollInterval = max(10, Int(pollInterval) ?? 60)
        store.updateSettings(s)
        KeychainService.saveToken(token)
    }

    private func deleteRepo(_ repo: Repository) {
        var s = store.settings
        s.repositories.removeAll { $0.id == repo.id }
        store.updateSettings(s)
    }
}
```

> `RepoFormView` 保留（在 SettingsView.swift 末尾），内容不变。

- [ ] **Step 2: 构建并运行所有测试**

```bash
cd /Users/norman/development/gitlab-monitor
xcodegen generate
xcodebuild -project GitLabMonitor.xcodeproj -scheme GitLabMonitor -destination 'platform=macOS' build 2>&1 | tail -5
xcodebuild test -project GitLabMonitor.xcodeproj -scheme GitLabMonitor -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "PASS|FAIL|BUILD|Test Suite" | tail -15
```

期望：BUILD SUCCEEDED，所有测试 PASS

- [ ] **Step 3: 提交**

```bash
cd /Users/norman/development/gitlab-monitor
git add GitLabMonitor/Views/SettingsView.swift
git commit -m "feat: refactor SettingsView to two-step wizard, fix token URL"
```

---

## Task 5: 重新编译安装

- [ ] **Step 1: Release 构建**

```bash
cd /Users/norman/development/gitlab-monitor
xcodebuild -project GitLabMonitor.xcodeproj -scheme GitLabMonitor -configuration Release -derivedDataPath build/DerivedData build 2>&1 | tail -5
```

- [ ] **Step 2: 安装到 Applications**

```bash
cp -R build/DerivedData/Build/Products/Release/GitLabMonitor.app /Applications/
```

- [ ] **Step 3: 重启应用**

```bash
pkill -x GitLabMonitor 2>/dev/null; sleep 1; open /Applications/GitLabMonitor.app
echo "已重启"
```

- [ ] **Step 4: 手动验证清单**

1. 菜单栏出现 GitLab fox 图标
2. 左键点击 → MonitorView 弹出
3. 点击 popover **外部** → popover 自动关闭
4. 右键图标 → 显示"退出 GitLab Monitor"选项
5. 点击⚙️ → 设置页第一步（连接设置）弹出
6. 填入 GitLab URL + Token → 点击"下一步"
7. 第二步显示仓库列表，点"+添加仓库" → `ProjectSearchView` 弹出
8. 搜索框显示最近 5 个仓库，输入关键词可搜索
9. 选中仓库 → branch 下拉加载
10. 多选 + 改变搜索词 → 已选仓库不消失
11. 点击"添加" → 仓库出现在第二步列表
12. Token `?` 链接跳转到 `/-/profile/personal_access_tokens`

- [ ] **Step 5: 最终提交**

```bash
cd /Users/norman/development/gitlab-monitor
git add .
git commit -m "chore: release build and install v2"
```

---

## Spec 覆盖确认

| 需求 | 任务 |
|------|------|
| GitLab logo 菜单栏图标 | Task 1 |
| popover 点外部关闭 | Task 1 (NSEvent globalMonitor) |
| 右键退出 | Task 1 (NSMenu + quitApp) |
| Token URL 修正 `/-/profile/...` | Task 4 (SettingsView step1) |
| 设置页两步向导 | Task 4 |
| 已有连接配置时跳到第二步 | Task 4 (loadCurrentSettings) |
| GitLab API 搜索仓库 | Task 2 + Task 3 |
| 搜索默认显示最近 5 个 | Task 2 (per_page=5) |
| 多选仓库 | Task 3 (ProjectSearchView) |
| 搜索变化已选不丢失 | Task 3 (unlistedSelected 区域) |
| inline branch 下拉 + API 加载 | Task 3 |
| GitLab CE 14.10.2 兼容 | Task 2 (API v4 + `/-/profile/` URL) |

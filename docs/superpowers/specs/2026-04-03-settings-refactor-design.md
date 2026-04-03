# GitLab Monitor — 设置页重构设计文档

**日期：** 2026-04-03  
**状态：** 已确认

---

## 概述

本次改动包含三个部分：
1. 菜单栏图标改为 GitLab logo（单色模板图片）
2. Token 帮助链接 URL 修正
3. 设置页改为两步向导，第二步支持通过 GitLab API 多选仓库

---

## 改动 1：菜单栏图标

将 `circle.fill` SF Symbol 替换为 GitLab logo 图标。

- 在 `Assets.xcassets` 中添加 `gitlab-icon` 图片集，设置为 **Template Image**（macOS 自动适配深/浅色模式）
- `AppDelegate.updateIcon()` 改用 `NSImage(named: "gitlab-icon")`
- 图标大小：18×18pt，单色黑白 PDF 格式

---

## 改动 2：Token URL 修正

**旧：** `{gitlabUrl}/-/user_settings/personal_access_tokens`  
**新：** `{gitlabUrl}/-/profile/personal_access_tokens`

位置：`GitLabMonitor/Views/SettingsView.swift`

---

## 改动 3：设置页两步向导 + GitLab API 仓库搜索

### 3.1 新增 API 方法

在 `GitLabServiceProtocol` 和 `GitLabService` 中新增：

```swift
// 搜索项目列表（空 query 返回最近更新的 5 个）
func fetchProjects(gitlabUrl: String, token: String, search: String) async throws -> [GitLabProject]

// 拉取指定项目的 branch 列表
func fetchBranches(gitlabUrl: String, token: String, projectId: Int) async throws -> [GitLabBranch]
```

**API 端点：**
- 项目搜索：`GET /api/v4/projects?membership=true&order_by=last_activity_at&sort=desc&per_page=5&search=:query`
- Branch 列表：`GET /api/v4/projects/:id/branches?per_page=50`

### 3.2 新增数据模型

```swift
// GitLabMonitor/Models/GitLabProject.swift
struct GitLabProject: Identifiable, Decodable {
    let id: Int
    let name: String
    let pathWithNamespace: String  // e.g. "group/project"
    let defaultBranch: String?
}

// GitLabMonitor/Models/GitLabBranch.swift
struct GitLabBranch: Identifiable, Decodable {
    var id: String { name }
    let name: String
}
```

### 3.3 设置页两步向导

`SettingsView` 内部用 `@State private var step: Int = 1` 控制步骤切换。

**第一步：连接 GitLab**

```
┌─────────────────────────────┐
│ 连接设置              1/2   │
├─────────────────────────────┤
│ GitLab 地址                 │
│ [https://gitlab.company.com]│
│                             │
│ Access Token                │
│ [glpat-xxxx         ]       │
│ 需要 read_api 权限  [?]     │
│                             │
│ 轮询间隔: [60] 秒           │
├─────────────────────────────┤
│              [下一步 →]     │  ← URL 和 Token 都非空才可点
└─────────────────────────────┘
```

- 点击"下一步"先保存 URL/Token/轮询间隔，再切换到第二步
- `?` 链接指向 `{gitlabUrl}/-/profile/personal_access_tokens`

**第二步：选择仓库**

```
┌─────────────────────────────┐
│ 监控仓库        已选3  2/2  │
├─────────────────────────────┤
│ 🔍 [搜索仓库名称...      ]  │
├─────────────────────────────┤
│ 已选择                      │
│ ☑ group/frontend  [main  ▼] │
│ ☑ group/backend   [main  ▼] │
├── 搜索结果 ─────────────────┤
│ ☑ group/backend   [main  ▼] │
│ ☐ group/data-api            │
│ ☐ group/mobile              │
├─────────────────────────────┤
│ [← 返回]      [完成]        │
└─────────────────────────────┘
```

**行为细节：**
- 打开第二步时立即调用 `fetchProjects(search: "")` 展示默认 5 个项目
- 用户输入搜索词时 debounce 300ms 后重新请求
- 选中仓库后 inline 显示 branch 下拉，立即调用 `fetchBranches` 填充选项，默认选中 `defaultBranch`
- **已选仓库始终显示在顶部区域**，搜索变化不影响已选状态
- 已选仓库若出现在搜索结果中，显示为选中状态（可点击取消）
- 点击"完成"将所有已选仓库保存到 `store.settings.repositories`，已存在的仓库不重复添加，关闭设置页

### 3.4 文件结构

```
GitLabMonitor/
├── Models/
│   ├── GitLabProject.swift   (新增)
│   └── GitLabBranch.swift    (新增)
├── Services/
│   ├── GitLabServiceProtocol.swift  (修改：新增 fetchProjects/fetchBranches)
│   └── GitLabService.swift          (修改：实现新方法)
├── Views/
│   └── SettingsView.swift    (修改：两步向导 + ProjectSearchView)
└── Assets.xcassets/
    └── gitlab-icon.imageset/  (新增)
```

`RepoFormView`（手动填写仓库路径）保留，供"编辑仓库"使用（修改已有仓库的 branch）。添加新仓库改为通过 API 搜索选择。

---

## 错误处理

| 场景 | 行为 |
|------|------|
| fetchProjects 失败 | 显示"加载失败，请检查连接设置" + 重试按钮 |
| fetchBranches 失败 | branch 下拉显示"加载失败"，允许手动输入 |
| 搜索无结果 | 显示"未找到相关仓库" |

---

## 不在范围内

- 仓库分页（超过 5 条搜索结果的分页）
- 仓库分组/排序选项
- 已有仓库的 branch 从 API 重新获取（编辑时仍为手动输入）

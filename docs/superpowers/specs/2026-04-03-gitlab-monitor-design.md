# GitLab Monitor — macOS 菜单栏应用设计文档

**日期：** 2026-04-03  
**状态：** 已确认

---

## 概述

一个原生 macOS 菜单栏应用，实时监控 GitLab CI/CD Pipeline 状态。应用常驻 macOS 状态栏（右上角），通过图标颜色反映所有已配置仓库的 Pipeline 整体健康状态。

---

## 技术选型

- **语言：** Swift
- **UI 框架：** SwiftUI + AppKit
- **菜单栏：** `NSStatusItem`
- **最低支持系统：** macOS 13.0 (Ventura)
- **无 Dock 图标** — 后台常驻

---

## 架构

```
GitLabMonitor.app
├── AppDelegate          — 应用入口，创建 NSStatusItem
├── StatusBarController  — 管理菜单栏图标颜色/状态
├── PopoverController    — 管理下拉面板的显示/隐藏
├── MonitorView          — SwiftUI 面板：仓库列表 + 状态
├── SettingsView         — SwiftUI 设置页：增删仓库、参数配置
├── GitLabService        — 封装 GitLab API 调用（Pipeline 状态）
├── RepositoryStore      — 数据层：持久化仓库配置到 UserDefaults
└── PipelinePoller       — 定时轮询，驱动状态更新
```

**数据流：**
```
PipelinePoller（定时器）→ GitLabService（API 调用）→ RepositoryStore（状态缓存）
  → StatusBarController（图标更新）+ MonitorView（UI 刷新）
```

---

## 数据模型

### 仓库配置（持久化到 UserDefaults）
```swift
struct Repository: Codable, Identifiable {
    let id: UUID
    var name: String         // 显示名称
    var projectPath: String  // GitLab 项目 ID 或 namespace/project 路径
    var branch: String       // 监控的 branch
}
```

### 全局设置（持久化到 UserDefaults）
```swift
struct AppSettings: Codable {
    var gitlabUrl: String     // 示例：https://gitlab.company.com
    var pollInterval: Int     // 轮询间隔（秒），默认 60
    var repositories: [Repository]
}
```

### Access Token
- 存储在系统 **Keychain**（不存 UserDefaults，更安全）
- Keychain Key：`com.gitlab-monitor.access-token`

### Pipeline 状态
```swift
enum PipelineStatus {
    case running   // 图标：黄色
    case pending   // 图标：黄色
    case success   // 图标：绿色
    case failed    // 图标：红色
    case canceled  // 图标：灰色
    case unknown   // 图标：灰色（无数据或请求出错）
}
```

---

## GitLab API

每个仓库调用以下接口：

```
GET /api/v4/projects/:id/pipelines?ref=:branch&per_page=1&order_by=id&sort=desc
Header: PRIVATE-TOKEN: <access_token>
```

返回指定 branch 的最新一条 Pipeline，取 `status` 字段映射到 `PipelineStatus`。

Token 所需权限范围：**`read_api`**

---

## 菜单栏图标

- 使用 SF Symbols `circle.fill`
- 颜色反映**所有仓库中最严重的状态**：
  - 任意仓库 `failed` → 红色
  - 任意仓库 `running` 或 `pending` → 黄色
  - 全部 `success` → 绿色
  - 无数据 / 全部出错 → 灰色

---

## UI：监控面板（MonitorView）

点击菜单栏图标后弹出。

```
┌─────────────────────────────────┐
│ GitLab Monitor              ⚙️  │  ← 齿轮图标打开设置
├─────────────────────────────────┤
│ 🟢 frontend   main      ✓ 成功   │
│    2 分钟前                  ↗  │  ← ↗ 用浏览器打开 Pipeline 页面
├─────────────────────────────────┤
│ 🟡 backend    develop  ↻ 运行中  │
│    刚刚                      ↗  │
├─────────────────────────────────┤
│ 🔴 api        main      ✗ 失败   │
│    5 分钟前                  ↗  │
└─────────────────────────────────┘
```

- 每行显示：状态圆点、仓库名、branch、Pipeline 状态、更新时间、跳转链接
- 点击 `↗` 用默认浏览器打开对应 Pipeline 页面

---

## UI：设置页（SettingsView）

```
┌──────────────────────────────────────┐
│ 设置                                 │
├──────────────────────────────────────┤
│ GitLab 地址：[___________________]   │
│                                      │
│ Access Token：[__________________]   │
│ 需要 read_api 权限             [?]  │  ← ? 打开 {gitlabUrl}/-/user_settings/personal_access_tokens
│                                      │
│ 轮询间隔：[60] 秒                    │
├──────────────────────────────────────┤
│ 仓库列表                    [+ 添加] │
│ ▸ frontend   main    [编辑] [删除]   │
│ ▸ backend    develop [编辑] [删除]   │
└──────────────────────────────────────┘
```

- **GitLab 地址**和 **Token** 全局共用（单一 GitLab 实例）
- **`?` 帮助链接**：点击打开 `{gitlabUrl}/-/user_settings/personal_access_tokens`，引导用户创建 Token
- **Token 提示文字**：内联显示"需要 read_api 权限"
- **轮询间隔**：可编辑整数（单位：秒）
- **添加仓库**表单：显示名称、项目路径（如 `group/project`）、branch

---

## 错误处理

| 场景 | 行为 |
|------|------|
| 网络错误 | 该仓库显示灰色 `unknown`，tooltip 提示"连接失败" |
| 401 未授权 | 所有仓库变灰，面板提示"Token 无效，请检查设置" |
| 404 项目不存在 | 该仓库行显示"项目未找到" |
| 任意轮询失败 | 静默等待下次重试，不影响其他仓库 |

---

## 测试策略

- `GitLabService` 通过协议抽象 HTTP 层，便于 mock 测试 API 解析逻辑
- `PipelinePoller` 使用 mock service 验证状态更新逻辑
- UI 层手动验证

---

## 不在范围内

- 多个 GitLab 实例
- 状态变化时的系统通知/提醒（未来功能）
- 深色/浅色模式图标适配（使用系统自适应 SF Symbols，已自动处理）

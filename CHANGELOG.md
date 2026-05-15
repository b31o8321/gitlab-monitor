# Changelog / 更新日志

## [Unreleased]

---

## [0.1.3] — 2026-05-15

### English

#### Fixed
- Restore configured repositories on app launch (states were not seeded from saved settings; the popover showed "no repositories" until the user re-opened Settings and saved again)
- Manual refresh now bypasses the in-flight poll guard so the reload button always triggers a new poll (previously silently dropped when a slow poll was still pending, e.g. during a network stall)

### 中文

#### 修复
- 启动时自动恢复已配置的仓库列表（之前未把保存的设置同步到运行时状态，导致弹窗显示"暂无仓库"，必须重新走一遍设置才能生效）
- 手动刷新按钮跳过"轮询进行中"守卫，每次点击都立即触发新一轮抓取（之前网络卡住时，刷新会被静默丢弃）

---

## [0.1.0] — 2026-04-03

### English

#### Added
- macOS menu bar app with GitLab CI/CD pipeline monitoring
- Full-color orange GitLab icon in menu bar
- Right-click menu bar icon to quit
- Two-step settings wizard:
  - Step 1: GitLab URL, Access Token, poll interval
  - Step 2: Search and select repositories via GitLab API
- GitLabProject and GitLabBranch models for project discovery
- Dynamic branch selection with BranchSelector and BranchResolver
- Configurable polling interval with minimum 10-second guard
- Concurrent poll protection (backpressure guard)
- Token stored securely in macOS Keychain
- Color-coded pipeline status indicators
- GitHub Actions workflow: auto-build and publish DMG on version tag push

#### Fixed
- Encode slash as `%2F` in project path for GitLab API compatibility
- Activate app before showing settings window so inputs are editable
- Trim whitespace from URL and token inputs
- Prevent polling storm on settings changes
- Settings window rendered as proper NSWindow
- Normalize GitLab URL (strip trailing slash)

---

### 中文

#### 新增
- macOS 菜单栏 GitLab CI/CD 流水线监控应用
- 菜单栏显示全彩橙色 GitLab 图标
- 右键菜单栏图标可退出应用
- 两步设置向导：
  - 第一步：配置 GitLab 地址、Access Token、轮询间隔
  - 第二步：通过 GitLab API 搜索并选择监控仓库
- 新增 GitLabProject 和 GitLabBranch 模型，支持项目发现
- 新增 BranchSelector 和 BranchResolver，支持动态分支选择
- 轮询间隔可配置，最小限制 10 秒
- 并发轮询保护（防重入守卫）
- Access Token 安全存储于 macOS 钥匙串
- 流水线状态颜色标识
- GitHub Actions 工作流：推送版本 tag 自动编译并发布 DMG

#### 修复
- GitLab API 路径中斜杠编码为 `%2F`
- 修复设置窗口弹出时输入框无法编辑的问题
- URL 和 Token 输入自动去除首尾空格
- 修复设置变更触发轮询风暴的问题
- 设置窗口改为正确的 NSWindow 实现
- GitLab 地址自动去除末尾斜杠

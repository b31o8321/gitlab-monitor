# Changelog / 更新日志

## [Unreleased]

---

## [0.1.8] — 2026-05-19

### English

#### Added
- Auto-update from GitHub Releases. On launch + every 6 hours, the app queries `GET /repos/<owner>/<repo>/releases/latest`, compares `tag_name` against `CFBundleShortVersionString`, and shows an in-popover banner when a newer version is published. Clicking "更新" opens a confirm dialog with the release notes; choosing "现在更新" downloads the DMG to `~/Library/Caches/`, hands off to a one-shot bash updater (mounts DMG → copies app to its current install path → clears quarantine → relaunches), and quits.
- Manual "检查更新" button in Settings, including current version and last-checked timestamp.
- "跳过该版本" option in both the banner and confirm dialog: persists the skipped version in UserDefaults so silent checks ignore it (manual check still surfaces it).

### 中文

#### 新增
- 自动从 GitHub Release 检查 + 安装更新。启动时和之后每 6 小时拉取 GitHub Release，发现更高版本时菜单栏弹窗顶部出现"v0.1.x 可用 [更新]"横幅。点"更新"弹窗显示版本说明并要求确认，选"现在更新"后自动下载 DMG、清 quarantine、替换 app 并重启。
- 设置里新增"应用更新"区块，可手动"检查更新"并查看上次检查时间。
- 横幅和确认弹窗都可以"跳过该版本"，跳过的版本号存在 UserDefaults 里，自动检查时不再提醒（手动检查仍会显示）。

> **注意**：自动更新逻辑本身在 v0.1.8 里。从 v0.1.7 升级到 v0.1.8 仍需手动安装一次（xattr -cr + 拖到 Applications）。v0.1.9 起就完全自动。

---

## [0.1.7] — 2026-05-19

### English

#### Added
- Running pipelines now show a progress bar plus elapsed/baseline times (e.g. `[████████░░░░] 1m20s / 2m30s`). The baseline is the average duration of the last 5 successful pipelines on the same branch, fetched via GitLab API. Row ticks every 5 seconds so the elapsed portion stays live. When elapsed exceeds the baseline the bar fills and shows "超过历史 X". When no baseline exists (first deployment, etc.), only the elapsed time is shown.
- Version number displayed next to the app name in the popover header (`GitLab Monitor v0.1.7`), so it's obvious whether you're on the latest build.

#### Changed
- Access token is now stored in UserDefaults instead of macOS Keychain. With ad-hoc signing the keychain ACL was tied to the code signature, so each rebuild made the previous token unreadable — colleagues had to re-paste the token on every upgrade. UserDefaults survives reinstalls cleanly. A one-shot migration on first launch pulls any existing Keychain token forward, so no manual action is needed.
- GitLab timestamp parsing accepts both with and without fractional seconds, and falls back across `started_at` / `created_at` / `updated_at` so the progress bar appears reliably across GitLab versions.

### 中文

#### 新增
- 运行中的 pipeline 显示进度条 + 已用/预计耗时（如 `[████████░░░░] 1m20s / 2m30s`）。基线取该分支最近 5 次成功流水线的平均耗时，从 GitLab API 拉取。Row 每 5 秒刷新一次。超时则进度条占满 + 显示"超过历史 X"。若从未成功过，只显示已运行时间。
- 弹窗头部显示应用版本号（`GitLab Monitor v0.1.7`），方便判断是不是最新版。

#### 变更
- Token 改存 UserDefaults，不再使用 Keychain。原因：ad-hoc 签名每次重新构建签名都不一样，macOS Keychain ACL 会拒绝读取旧版本写入的 token，导致同事每次升级都得重新粘贴 token。UserDefaults 不受签名变化影响，重装后 token + GitLab URL + 仓库列表全部保留。首次启动会自动从老 Keychain 把 token 搬过来，无需手动操作。
- GitLab 时间戳解析同时兼容带毫秒与不带毫秒两种格式，并依次回退 `started_at` / `created_at` / `updated_at`，进度条在各种 GitLab 版本下都能稳定显示。

---

## [0.1.6] — 2026-05-18

### English

#### Changed
- "Fixed branch" selector in Settings is now a searchable combobox (text input + suggestion list) instead of a flat dropdown. Branches are fetched via GitLab's `?search=` parameter on each keystroke (debounced), so projects with hundreds of branches no longer hide behind a per_page=100 cap. The dropdown caret toggles the list; selecting an item fills the field and dismisses the list.

### 中文

#### 变更
- 设置里"固定分支"改成可搜索输入框 + 候选列表（替代原来的下拉菜单）。输入时通过 GitLab API 的 `?search=` 参数实时查询（300ms 防抖），不再受 100 个分支的硬上限限制。点右边的箭头按钮也可以展开/收起列表，点击候选项填入输入框并自动关闭。

---

## [0.1.5] — 2026-05-15

### English

#### Changed
- Replaced the v0.1.4 `Install.command` bundled in the DMG with a Chinese-language `安装说明.txt`. On macOS Sequoia, unsigned `.command` scripts hit the same Gatekeeper wall as the app itself, making the "one-click" promise misleading. The text file now spells out the manual `xattr -cr` step plus a full configuration walkthrough (GitLab URL, Personal Access Token creation, branch matching modes, status colors)
- README install section rewritten to lead with the `xattr -cr` one-liner as the canonical install path

### 中文

#### 变更
- v0.1.4 在 DMG 里放的 `Install.command` 在 macOS Sequoia 上同样会被 Gatekeeper 拦截，所谓"一键"名不副实，已移除。改为附带中文 `安装说明.txt`，写清楚手动 `xattr -cr` 命令、Token 生成步骤、URL 配置位置、分支匹配模式（固定 / 动态日期 / 自定义正则）、状态颜色含义等
- README 安装段落重写，直接以 `xattr -cr` 一行命令为主流程

---

## [0.1.4] — 2026-05-15

### English

#### Added
- `Install.command` bundled inside the DMG: one-click installer that copies the app to `/Applications`, clears the quarantine attribute, and launches it — avoids the misleading "damaged" dialog on internal distribution

#### Docs
- README documents the new `Install.command` flow and the manual `xattr -cr` fallback

### 中文

#### 新增
- DMG 内附带 `Install.command` 一键安装脚本：自动复制到 `/Applications`、清除 macOS 隔离属性并启动，规避内部分发时 "已损坏" 的误报弹窗

#### 文档
- README 新增 `Install.command` 安装流程说明，以及手动 `xattr -cr` 备选方案

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

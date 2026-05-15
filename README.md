# GitLab Monitor

A lightweight macOS menu bar app that monitors your GitLab CI/CD pipeline status in real time.

轻量级 macOS 菜单栏应用，实时监控 GitLab CI/CD 流水线状态。

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

---

## English

### Features

- Live pipeline status for multiple GitLab repositories
- Color-coded indicators: green (passed), red (failed), yellow (running), gray (unknown)
- Configurable polling interval (minimum 10 seconds)
- Search and select repositories directly from GitLab
- Token stored securely in macOS Keychain
- Right-click the menu bar icon to quit

### Requirements

- macOS 13 Ventura or later
- A GitLab instance (gitlab.com or self-hosted)
- A GitLab Personal Access Token with `read_api` scope

### Installation

1. Download `GitLabMonitor.dmg` from [Releases](https://github.com/b31o8321/gitlab-monitor/releases)
2. Open the DMG
3. **Double-click `Install.command`** — it copies the app to `/Applications`, clears the macOS quarantine flag, and launches it. A GitLab icon will appear in your menu bar.

> **Why `Install.command`?** This app is ad-hoc signed (no paid Apple Developer ID), so when you download the DMG via a browser, macOS attaches a quarantine attribute that triggers a misleading "**GitLabMonitor is damaged and can't be opened**" dialog on first launch. `Install.command` removes that attribute. If macOS warns about the script on first run, right-click it → **Open** to allow execution.
>
> Prefer manual install? Drag the app to `/Applications`, then run in Terminal:
>
> ```bash
> xattr -cr /Applications/GitLabMonitor.app && open /Applications/GitLabMonitor.app
> ```

### Getting a GitLab Personal Access Token

1. Sign in to your GitLab instance
2. Go to **User Settings → Access Tokens**
   - Direct link: `https://gitlab.com/-/profile/personal_access_tokens` (replace the domain for self-hosted instances)
3. Click **Add new token**
4. Fill in:
   - **Token name**: e.g. `gitlab-monitor`
   - **Expiration date**: choose an appropriate date
   - **Scopes**: check `read_api`
5. Click **Create personal access token**
6. **Copy the token now** — it will not be shown again

### Setup

**Step 1 — Connection**

Click the GitLab icon in the menu bar, then click the gear icon (⚙️) to open Settings.

| Field | Description |
|---|---|
| **GitLab URL** | Your GitLab instance URL, e.g. `https://gitlab.com` or `https://git.example.com` |
| **Access Token** | The `glpat-...` token you just created |
| **Poll Interval** | How often to check pipeline status, in seconds (minimum 10) |

Click **Next →** to proceed.

**Step 2 — Select Repositories**

Type in the search box to find projects by name. Click a project to select it (highlighted). You can select multiple projects. Click **Done** to save.

### Building from Source

```bash
git clone https://github.com/b31o8321/gitlab-monitor.git
cd gitlab-monitor
xcodebuild -scheme GitLabMonitor -configuration Release build
```

Run tests:

```bash
xcodebuild test -scheme GitLabMonitor -destination 'platform=macOS'
```

---

## 中文

### 功能特性

- 同时监控多个 GitLab 仓库的流水线状态
- 颜色标识：绿色（通过）、红色（失败）、黄色（进行中）、灰色（未知）
- 可配置轮询间隔（最短 10 秒）
- 直接在应用内搜索并选择 GitLab 项目
- Access Token 安全存储于 macOS 钥匙串
- 右键菜单栏图标可退出应用

### 系统要求

- macOS 13 Ventura 及以上
- GitLab 实例（gitlab.com 或私有部署）
- 拥有 `read_api` 权限的 GitLab Personal Access Token

### 安装

1. 从 [Releases](https://github.com/b31o8321/gitlab-monitor/releases) 下载 `GitLabMonitor.dmg`
2. 打开 DMG
3. **双击 `Install.command`** —— 脚本会自动把 app 复制到 `/Applications`、清除 macOS 隔离属性、并启动应用。菜单栏出现 GitLab 图标即为成功。

> **为什么需要 `Install.command`？** 本应用使用 ad-hoc 签名（没有付费的 Apple Developer ID），从浏览器下载 DMG 后 macOS 会自动打上 quarantine 标记，首次打开会报"**"GitLabMonitor"已损坏，无法打开**"。`Install.command` 会清掉该标记。如果首次运行脚本时 macOS 拦截，**右键脚本 → 打开** 即可放行。
>
> 想手动安装？把 app 拖到 `/Applications`，然后在 Terminal 执行：
>
> ```bash
> xattr -cr /Applications/GitLabMonitor.app && open /Applications/GitLabMonitor.app
> ```

### 生成 GitLab Personal Access Token

1. 登录你的 GitLab 实例
2. 进入 **用户设置 → Access Tokens**
   - 直达链接：`https://gitlab.com/-/profile/personal_access_tokens`（私有部署请替换域名）
3. 点击 **Add new token**
4. 填写：
   - **Token name**：如 `gitlab-monitor`
   - **Expiration date**：选择合适的到期日期
   - **Scopes**：勾选 `read_api`
5. 点击 **Create personal access token**
6. **立即复制 Token**，离开页面后将无法再次查看

### 配置

**第一步 — 连接设置**

点击菜单栏 GitLab 图标，再点击齿轮图标（⚙️）打开设置。

| 字段 | 说明 |
|---|---|
| **GitLab 地址** | GitLab 实例地址，如 `https://gitlab.com` 或 `https://git.example.com` |
| **Access Token** | 刚才创建的 `glpat-...` Token |
| **轮询间隔** | 检查流水线状态的频率，单位秒（最小 10） |

点击 **下一步 →** 继续。

**第二步 — 选择仓库**

在搜索框中输入项目名称进行搜索，点击项目即可选中（蓝色高亮），支持多选。点击 **完成** 保存。

### 从源码构建

```bash
git clone https://github.com/b31o8321/gitlab-monitor.git
cd gitlab-monitor
xcodebuild -scheme GitLabMonitor -configuration Release build
```

运行测试：

```bash
xcodebuild test -scheme GitLabMonitor -destination 'platform=macOS'
```

---

## License / 许可证

MIT

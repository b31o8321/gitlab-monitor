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

This app is **ad-hoc signed** (no paid Apple Developer ID), so macOS Gatekeeper rejects it on first launch with a misleading "**GitLabMonitor is damaged and can't be opened**" dialog. There's one extra step the first time:

1. Download `GitLabMonitor.dmg` from [Releases](https://github.com/b31o8321/gitlab-monitor/releases)
2. Open the DMG, **drag `GitLabMonitor` into the `Applications` shortcut**
3. Open **Terminal** and run:
   ```bash
   xattr -cr /Applications/GitLabMonitor.app && open /Applications/GitLabMonitor.app
   ```

`xattr -cr` clears the macOS quarantine flag set by your browser. You only need to run it once. After this the app launches like any other.

> The DMG also contains `安装说明.txt` with a Chinese walkthrough of the same steps plus a configuration guide — useful when sharing this app inside your team.

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

本应用使用 **ad-hoc 签名**（没有付费的 Apple Developer ID），从浏览器下载 DMG 后 macOS Gatekeeper 默认拒绝运行，会报 **""GitLabMonitor" 已损坏，无法打开"**。首次安装需要多走一步：

1. 从 [Releases](https://github.com/b31o8321/gitlab-monitor/releases) 下载 `GitLabMonitor.dmg`
2. 打开 DMG，把 `GitLabMonitor` 图标**拖到 `Applications` 快捷方式**里
3. 打开 **Terminal**（启动台 → 其他 → 终端，或 Spotlight 搜 "Terminal"），粘贴这一行回车：
   ```bash
   xattr -cr /Applications/GitLabMonitor.app && open /Applications/GitLabMonitor.app
   ```

`xattr -cr` 用来清除浏览器下载时打上的 macOS 隔离标记。**只需要执行这一次**，之后双击应用就能正常打开。

> DMG 内还有一份 `安装说明.txt`，包含安装步骤、Token 生成方法、URL 配置位置、分支匹配模式（固定 / 按日期前缀动态匹配最新 / 自定义正则）等中文说明，发给同事用比较省心。

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

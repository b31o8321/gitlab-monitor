# GitLab Monitor

A lightweight macOS menu bar app that monitors your GitLab CI/CD pipeline status in real time.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- Live pipeline status for multiple GitLab repositories
- Color-coded indicators: green (passed), red (failed), yellow (running), gray (unknown)
- Configurable polling interval (minimum 10 seconds)
- Search and select repositories directly from GitLab
- Token stored securely in macOS Keychain
- Right-click the menu bar icon to quit

## Requirements

- macOS 13 Ventura or later
- A GitLab instance (gitlab.com or self-hosted)
- A GitLab Personal Access Token with `read_api` scope

## Installation

1. Download `GitLabMonitor.dmg` from [Releases](https://github.com/b31o8321/gitlab-monitor/releases)
2. Open the DMG and drag **GitLabMonitor.app** to your **Applications** folder
3. Launch the app — a GitLab icon appears in your menu bar

> **First launch on macOS:** If you see "cannot be opened because the developer cannot be verified", go to **System Settings → Privacy & Security** and click **Open Anyway**.

## Getting a GitLab Personal Access Token

1. Sign in to your GitLab instance
2. Go to **User Settings → Access Tokens**
   - Direct link: `https://gitlab.com/-/profile/personal_access_tokens` (replace domain for self-hosted)
3. Click **Add new token**
4. Fill in:
   - **Token name**: e.g. `gitlab-monitor`
   - **Expiration date**: choose an appropriate date
   - **Scopes**: check `read_api`
5. Click **Create personal access token**
6. **Copy the token now** — it won't be shown again

## Setup

### Step 1 — Connection

Click the GitLab icon in the menu bar, then click the gear icon (⚙️) to open Settings.

| Field | Description |
|---|---|
| **GitLab 地址** | Your GitLab instance URL, e.g. `https://gitlab.com` or `https://git.example.com` |
| **Access Token** | The `glpat-...` token you just created |
| **轮询间隔** | How often to check pipeline status, in seconds (minimum 10) |

Click **下一步 →** (Next) to verify the connection.

### Step 2 — Select Repositories

Type in the search box to find projects by name. Click a project to select it (highlighted in blue). You can select multiple projects.

Click **完成** (Done) to save. The menu bar popover will now show live pipeline statuses.

## Building from Source

```bash
git clone https://github.com/b31o8321/gitlab-monitor.git
cd gitlab-monitor
xcodebuild -scheme GitLabMonitor -configuration Release build
```

Run tests:

```bash
xcodebuild test -scheme GitLabMonitor -destination 'platform=macOS'
```

## License

MIT

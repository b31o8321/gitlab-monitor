# Changelog

## [Unreleased]

### Added
- Dynamic branch selection with BranchSelector and BranchResolver
- Refactored ProjectSearchView with debounced search and multi-select support
- Simplified SettingsView into a clean two-step wizard

## [0.1.0] — 2026-04-03

### Added
- macOS menu bar app with GitLab CI/CD pipeline monitoring
- Full-color orange GitLab icon in menu bar
- Right-click menu bar icon to quit
- Two-step settings wizard:
  - Step 1: GitLab URL, Access Token, poll interval
  - Step 2: Search and select repositories via GitLab API
- GitLabProject and GitLabBranch models for project discovery
- Configurable polling interval with minimum 10-second guard
- Concurrent poll protection (backpressure guard)
- Token stored securely in macOS Keychain
- Color-coded pipeline status indicators

### Fixed
- Encode slash as `%2F` in project path for GitLab API compatibility
- Activate app before showing settings window so inputs are editable
- Trim whitespace from URL and token inputs
- Prevent polling storm on settings changes
- Settings window rendered as proper NSWindow
- Normalize GitLab URL (strip trailing slash)

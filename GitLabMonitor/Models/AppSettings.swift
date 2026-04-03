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
        guard let data = UserDefaults.standard.data(forKey: "com.gitlab-monitor.appSettings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: "com.gitlab-monitor.appSettings")
    }
}

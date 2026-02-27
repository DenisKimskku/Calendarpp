import Foundation
import ServiceManagement

enum StartAtLoginManagerError: LocalizedError {
    case unavailable
    case requiresApplicationsInstall

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Start at login is unavailable on this macOS version."
        case .requiresApplicationsInstall:
            return "To enable Start at Login, calendar++ must be installed in the Applications folder."
        }
    }
}

struct StartAtLoginManager {
    private static func isInstalledInApplicationsFolder() -> Bool {
        let appPath = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        if appPath.hasPrefix("/Applications/") { return true }
        let userApplications = (NSHomeDirectory() as NSString).appendingPathComponent("Applications") + "/"
        return appPath.hasPrefix(userApplications)
    }

    static func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            throw StartAtLoginManagerError.unavailable
        }
        guard !enabled || isInstalledInApplicationsFolder() else {
            throw StartAtLoginManagerError.requiresApplicationsInstall
        }

        let service = SMAppService.mainApp
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }

    static func isEnabled() -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    static func needsUserApproval() -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .requiresApproval
    }

    /// Best-effort: keep the system login-item state aligned with the stored preference.
    /// Skips DerivedData/dev runs to avoid noisy failures; Homebrew installs should be in /Applications.
    static func syncToStoredPreferenceIfPossible() {
        guard #available(macOS 13.0, *) else { return }
        guard isInstalledInApplicationsFolder() else { return }

        let desired = UserDefaults.standard.bool(forKey: "startAtLogin")
        let status = SMAppService.mainApp.status
        let isRegistered = status != .notRegistered

        guard desired != isRegistered else { return }

        do {
            try setEnabled(desired)
        } catch {
            // Avoid retrying every launch if we can't apply; reflect reality in preferences.
            UserDefaults.standard.set(isRegistered, forKey: "startAtLogin")
        }
    }
}

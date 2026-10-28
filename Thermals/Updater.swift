import AppKit
import Sparkle
import UserNotifications

/// In-app updates through Sparkle. A scheduled find is announced gently, on the board and in one notification per version,
/// instead of Sparkle's window; Install brings that window up to download, verify, replace and relaunch.
@MainActor @Observable
final class Updater: NSObject {
    /// The version Sparkle has found and is holding for the user, until its update session ends.
    private(set) var available: String?
    @ObservationIgnored private var controller: SPUStandardUpdaterController?

    static let notifiedKey = "updateNotifiedVersion"
    private static let notificationID = "update"

    override init() {
        super.init()
        // Debug builds and tests never replace themselves with a release.
        #if !DEBUG
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
        UNUserNotificationCenter.current().delegate = self
        #endif
    }

    /// Shows a found update without Sparkle, for snapshots and previews.
    init(previewing version: String) {
        available = version
        super.init()
    }

    func install() {
        // A menu bar app is never frontmost on its own, so Sparkle's window would open behind other apps.
        NSApp.activate()
        controller?.checkForUpdates(nil)
    }

    /// Notification permission is asked only once there is something to announce.
    private func notify(_ version: String) {
        let defaults = UserDefaults.standard
        guard UpdateNotice.shouldNotify(version: version, lastNotified: defaults.string(forKey: Self.notifiedKey)) else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert])) == true, available == version else { return }
            let content = UNMutableNotificationContent()
            content.title = "Thermals \(version) is available"
            content.body = "Click to install it."
            guard (try? await center.add(UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: nil))) != nil else { return }
            defaults.set(version, forKey: Self.notifiedKey)
        }
    }
}

enum UpdateNotice {
    /// One notification per version; a version already announced only stays on the board.
    static func shouldNotify(version: String, lastNotified: String?) -> Bool {
        version != lastNotified
    }
}

extension Updater: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        available = update.displayVersionString
        if !handleShowingUpdate { notify(update.displayVersionString) }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.notificationID])
    }

    func standardUserDriverWillFinishUpdateSession() {
        available = nil
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.notificationID])
    }
}

extension Updater: @preconcurrency UNUserNotificationCenterDelegate {
    /// The popover being open makes the app active, which would otherwise swallow the banner.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        install()
        completionHandler()
    }
}

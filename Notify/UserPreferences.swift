import Foundation

final class UserPreferences {
    static let shared = UserPreferences()
    private let defaults = UserDefaults.standard
    private let key = "logDefaultDeliveryEnabled"

    /// Default = `true` so the feature works out-of-the-box.
    var logDefaultDelivery: Bool {
        get { defaults.object(forKey: key) as? Bool ?? true }
        set { defaults.set(newValue, forKey: key) }
    }
}

import UIKit

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    let container: UserDefaults = .standard

    var wrappedValue: T {
        get {
            container.object(forKey: key) as? T ?? defaultValue
        }
        set {
            container.set(newValue, forKey: key)
        }
    }
}

extension UserDefaults {
    enum Keys {
        static let hasOnboarded = "hasOnboarded"
    }

    @UserDefault(key: Keys.hasOnboarded, defaultValue: false)
    static var hasOnboarded: Bool
}

func shouldShowOnboarding() {
    if UserDefaults.hasOnboarded {
        print("Dont show onboarding")
    } else {
        UserDefaults.hasOnboarded = true
        print("Show onboarding")
    }
}

shouldShowOnboarding()
shouldShowOnboarding()

/*
 Copyright 2018 New Vector Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

/// Store Riot specific app settings.
@objcMembers
final class RiotSettings: NSObject {
    
    // MARK: - Constants
    
    private enum UserDefaultsKeys {
        static let enableCrashReport = "enableCrashReport"
        static let enableRageShake = "enableRageShake"
        static let createConferenceCallsWithJitsi = "createConferenceCallsWithJitsi"
        static let userInterfaceTheme = "userInterfaceTheme"
        static let notificationsShowDecryptedContent = "showDecryptedContent"
        static let showJoinLeaveEvents = "showJoinLeaveEvents"
        static let showProfileUpdateEvents = "showProfileUpdateEvents"
        static let allowStunServerFallback = "allowStunServerFallback"
        static let stunServerFallback = "stunServerFallback"
        static let enableCrossSigning = "enableCrossSigning"
        static let enableDMKeyVerification = "enableDMKeyVerification"
    }
    
    static let shared = RiotSettings()
    
    // MARK: - Public
    
    // MARK: Notifications
    
    /// Indicate if `showDecryptedContentInNotifications` settings has been set once.
    var isShowDecryptedContentInNotificationsHasBeenSetOnce: Bool {
        return UserDefaults.standard.object(forKey: UserDefaultsKeys.notificationsShowDecryptedContent) != nil
    }
    
    /// Indicate if encrypted messages content should be displayed in notifications.
    var showDecryptedContentInNotifications: Bool {
        get {
            return UserDefaults.standard.bool(forKey: UserDefaultsKeys.notificationsShowDecryptedContent)
        } set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.notificationsShowDecryptedContent)
        }
    }
    
    /// Indicate if the user wants to display the join and leave events in the room history.
    /// (No by default)
    var showJoinLeaveEvents: Bool {
        get {
            return UserDefaults.standard.bool(forKey: UserDefaultsKeys.showJoinLeaveEvents)
        } set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.showJoinLeaveEvents)
        }
    }
    
    /// Indicate if the user wants to display the profile update events (avatar / displayname) in the room history.
    /// (No by default)
    var showProfileUpdateEvents: Bool {
        get {
            return UserDefaults.standard.bool(forKey: UserDefaultsKeys.showProfileUpdateEvents)
        } set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.showProfileUpdateEvents)
        }
    }
    
    // MARK: User interface
    
    var userInterfaceTheme: String? {
        get {
            return UserDefaults.standard.string(forKey: UserDefaultsKeys.userInterfaceTheme)
        } set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.userInterfaceTheme)
        }
    }
    
    // MARK: Other
    
    /// Indicate if `enableCrashReport` settings has been set once.
    var isEnableCrashReportHasBeenSetOnce: Bool {
        return UserDefaults.standard.object(forKey: UserDefaultsKeys.enableCrashReport) != nil
    }
    
    var enableCrashReport: Bool {
        get {
            return UserDefaults.standard.bool(forKey: UserDefaultsKeys.enableCrashReport)
        } set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.enableCrashReport)
        }
    }
    
    var enableRageShake: Bool {
        get {
            return UserDefaults.standard.bool(forKey: UserDefaultsKeys.enableRageShake)
        } set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.enableRageShake)
        }
    }
    
    // MARK: Labs
    
    var createConferenceCallsWithJitsi: Bool {
        get {
            return UserDefaults.standard.bool(forKey: UserDefaultsKeys.createConferenceCallsWithJitsi)
        } set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.createConferenceCallsWithJitsi)
        }
    }
    
    var enableDMKeyVerification: Bool {
        get {
            return UserDefaults.standard.bool(forKey: UserDefaultsKeys.enableDMKeyVerification)
        } set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.enableDMKeyVerification)
        }
    }

    var enableCrossSigning: Bool {
        get {
            return UserDefaults.standard.bool(forKey: UserDefaultsKeys.enableCrossSigning)
        } set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.enableCrossSigning)
        }
    }

    // MARK: Calls

    /// Indicate if `allowStunServerFallback` settings has been set once.
    var isAllowStunServerFallbackHasBeenSetOnce: Bool {
        return UserDefaults.standard.object(forKey: UserDefaultsKeys.allowStunServerFallback) != nil
    }

    var allowStunServerFallback: Bool {
        get {
            return UserDefaults.standard.bool(forKey: UserDefaultsKeys.allowStunServerFallback)
        } set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.allowStunServerFallback)
        }
    }

    var stunServerFallback: String? {
        return UserDefaults.standard.string(forKey: UserDefaultsKeys.stunServerFallback)
    }
}

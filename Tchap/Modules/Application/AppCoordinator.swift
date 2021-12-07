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
import Intents

final class AppCoordinator: AppCoordinatorType {
    
    // MARK: - Constants
    
    private enum Constants {
        static let expiredAccountError: String = "ORG_MATRIX_EXPIRED_ACCOUNT"
        static let lastAppVersionWhichRequiresCacheClearing: AppVersion = AppVersion(bundleShortVersion: "1.2.0", bundleVersion: "1")
    }
    
    // MARK: - Properties
  
    // MARK: Private
    
    private let rootRouter: RootRouterType
    
    private let appVersionCheckerStore: AppVersionCheckerStoreType
    private let appVersionChecker: AppVersionChecker
    private var registrationService: RegistrationServiceType?
    private var pendingCheckAppVersionOperation: MXHTTPOperation?
    private let activityIndicatorPresenter: ActivityIndicatorPresenterType
    
//    private weak var splitViewCoordinator: SplitViewCoordinatorType?
    private weak var homeCoordinator: HomeCoordinatorType?
    private weak var appVersionUpdateCoordinator: AppVersionUpdateCoordinatorType?
    
    private weak var expiredAccountAlertController: UIAlertController?
    private var accountValidityService: AccountValidityServiceType?
    
    private var pendingRoomIdOrAlias: String?
    private var pendingEventId: String?
    
    /// Main user Matrix session
    private var mainSession: MXSession? {
        return MXKAccountManager.shared().activeAccounts.first?.mxSession
    }
  
    // MARK: Public
    
    var childCoordinators: [Coordinator] = []
    
    // MARK: - Setup
    
    init(router: RootRouterType) {
        self.rootRouter = router
        
        let clientConfigurationService = ClientConfigurationService()
        let appVersionCheckerStore = AppVersionCheckerStore()
        self.appVersionChecker = AppVersionChecker(clientConfigurationService: clientConfigurationService, appVersionCheckerStore: appVersionCheckerStore)
        self.appVersionCheckerStore = appVersionCheckerStore
        self.activityIndicatorPresenter = ActivityIndicatorPresenter()
    }
    
    // MARK: - Public methods
    
    func start() {
        // If main user exists, user is logged in
        if let mainSession = self.mainSession {
            // Check whether a clear cache is required before launching the app
            if AppVersion.isLastUsedVersionLowerThan(Constants.lastAppVersionWhichRequiresCacheClearing) {
                self.reloadSession(clearCache: true)
            } else {
//                self.showSplitView(session: mainSession)
                self.showHome(session: mainSession)
            }
        } else {
            self.showWelcome()
        }
        
        AppVersion.updateLastUsedVersion()
    }
    
    func handleUserActivity(_ userActivity: NSUserActivity, application: UIApplication) -> Bool {
//        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
//            self.presentActivityIndicator()
//            return self.universalLinkService.handleUserActivity(userActivity, completion: { (response) in
//                self.removeActivityIndicator()
//                switch response {
//                case .success(let parsingResult):
//                    switch parsingResult {
//                    case .registrationLink(let registerParams):
//                        self.handleRegisterAfterEmailValidation(registerParams)
//                    case .roomLink(let roomIdOrAlias, let eventID):
//                        _ = self.showRoom(with: roomIdOrAlias, onEventID: eventID)
//                    }
//                case .failure(let error):
//                    self.showError(error)
//                }
//            })
//        } else if userActivity.activityType == INStartAudioCallIntentIdentifier ||
//        userActivity.activityType == INStartVideoCallIntentIdentifier {
//            // Check whether a session is available (Ignore multi-accounts FTM)
//            guard let account = MXKAccountManager.shared()?.activeAccounts.first else {
//                return false
//            }
//            guard let session = account.mxSession else {
//                return false
//            }
//            let interaction = userActivity.interaction
//
//            let finalRoomID: String?
//            // Check roomID provided by Siri intent
//            if let roomID = userActivity.userInfo?["roomID"] as? String {
//                finalRoomID = roomID
//            } else {
//                // We've launched from calls history list
//                let person: INPerson?
//
//                if let audioCallIntent = interaction?.intent as? INStartAudioCallIntent {
//                    person = audioCallIntent.contacts?.first
//                } else if let videoCallIntent = interaction?.intent as? INStartVideoCallIntent {
//                    person = videoCallIntent.contacts?.first
//                } else {
//                    person = nil
//                }
//
//                finalRoomID = person?.personHandle?.value
//            }
//
//            if let roomID = finalRoomID {
//                let isVideoCall = userActivity.activityType == INStartVideoCallIntentIdentifier
//                var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
//
//                // Start background task since we need time for MXSession preparation because our app can be launched in the background
//                if application.applicationState == .background {
//                    backgroundTaskIdentifier = application.beginBackgroundTask(expirationHandler: nil)
//                }
//
//                session.callManager.placeCall(inRoom: roomID, withVideo: isVideoCall, success: { (call) in
//                    if application.applicationState == .background {
//                        let center = NotificationCenter.default
//                        var token: NSObjectProtocol?
//                        token = center.addObserver(forName: Notification.Name(kMXCallStateDidChange), object: call, queue: nil, using: { [weak center] (note) in
//                            if call.state == .ended {
//                                if let bgTaskIdentifier = backgroundTaskIdentifier {
//                                    application.endBackgroundTask(bgTaskIdentifier)
//                                }
//                                if let obsToken = token {
//                                    center?.removeObserver(obsToken)
//                                }
//                            }
//                        })
//                    }
//                }, failure: { (error) in
//                    if let bgTaskIdentifier = backgroundTaskIdentifier {
//                        application.endBackgroundTask(bgTaskIdentifier)
//                    }
//                })
//            } else {
//                let error = NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: TchapL10n.errorMessageDefault])
//                self.showError(error)
//            }
//
//            return true
//        }
        return false
    }

    func handlePermalinkFragment(_ fragment: String) -> Bool {
//        // Handle the permalink fragment with the universal link service
//        return self.universalLinkService.handleFragment(fragment, completion: { (response) in
//            switch response {
//            case .success(let parsingResult):
//                switch parsingResult {
//                case .registrationLink:
//                    // We don't expect a registration link from a permalink, we ignore this case here.
//                    MXLog.debug("[AppCoordinator] handlePermalinkFragment: unexpected fragment (registration link)")
//                case .roomLink(let roomIdOrAlias, let eventID):
//                    _ = self.showRoom(with: roomIdOrAlias, onEventID: eventID)
//                }
//            case .failure(let error):
//                self.showError(error)
//            }
//        })
        return false
    }
    
    func resumeBySelectingRoom(with roomId: String) {
        guard let account = MXKAccountManager.shared().accountKnowingRoom(withRoomIdOrAlias: roomId),
            let homeCoordinator = self.homeCoordinator,
            let room = account.mxSession.room(withRoomId: roomId) else {
                return
        }
        
        if room.summary.membership == .invite {
            homeCoordinator.scrollToRoom(with: roomId, animated: false)
        } else {
            homeCoordinator.showRoom(with: roomId, onEventID: nil)
        }
    }
    
    func showRoom(with roomIdOrAlias: String, onEventID eventID: String? = nil) -> Bool {
        guard let homeCoordinator = self.homeCoordinator, let session = self.mainSession else {
                return false
        }
        
        self.cancelPendingRoomSelection()
        
        // Postpone the action if the session didn't loaded the data from the store yet
        if session.state.rawValue < MXSessionState.storeDataReady.rawValue {
            self.postponeRoomSelection(with: roomIdOrAlias, onEventID: eventID)
            return false
        }
        
        // Check whether the room is known by the current user.
        let room: MXRoom? = roomIdOrAlias.hasPrefix("#") ? session.room(withAlias: roomIdOrAlias) : session.room(withRoomId: roomIdOrAlias)
        
        if let room = room, room.summary.membership == .join {
            homeCoordinator.showRoom(with: room.roomId, onEventID: eventID)
        } else {
            // Try to preview the unknown room.
            homeCoordinator.showRoomPreview(with: roomIdOrAlias, roomName: room?.summary.displayname, onEventID: eventID)
        }
        
        return true
    }
    
    func checkMinAppVersionRequirements() {
        guard self.pendingCheckAppVersionOperation == nil else {
            return
        }
        
        self.pendingCheckAppVersionOperation = self.appVersionChecker.checkCurrentAppVersion { (versionResult) in
            switch versionResult {
            case .upToDate, .unknown:
                break
            case .shouldUpdate(versionInfo: let versionInfo):
                MXLog.debug("[AppCoordinator] App should be upated with \(versionInfo)")
                self.presentApplicationUpdate(with: versionInfo)
            }
            self.pendingCheckAppVersionOperation = nil
        }
    }
    
    // MARK: - Private methods
    
    private func showWelcome() {
        let welcomeCoordinator = WelcomeCoordinator(router: self.rootRouter)
        welcomeCoordinator.delegate = self
        welcomeCoordinator.start()
        self.add(childCoordinator: welcomeCoordinator)
    }
    
    // Disable usage of UISplitViewController for the moment
//    private func showSplitView(session: MXSession) {
//        let splitViewCoordinator = SplitViewCoordinator(router: self.rootRouter, session: session)
//        splitViewCoordinator.start()
//        self.add(childCoordinator: splitViewCoordinator)
//
//        self.registerLogoutNotification()
//    }
    
    func showHome(session: MXSession) {
        // Remove the potential existing home coordinator.
        self.removeHome()
        
        let homeCoordinator = HomeCoordinator(session: session)
        homeCoordinator.start()
        homeCoordinator.delegate = self
        self.add(childCoordinator: homeCoordinator)
        
        homeCoordinator.overrideContactManagerUsersDiscovery(true)
        
        self.rootRouter.setRootModule(homeCoordinator)
        
        self.homeCoordinator = homeCoordinator
        
        self.registerLogoutNotification()
        self.registerIgnoredUsersDidChangeNotification()
        self.registerDidCorruptDataNotification()
        
        // Track ourself the server error related to an expired account.
        AppDelegate.theDelegate().ignoredServerErrorCodes = [Constants.expiredAccountError]
        self.registerTrackedServerErrorNotification()
    }
    
    private func removeHome() {
        if let homeCoordinator = self.homeCoordinator {
            homeCoordinator.overrideContactManagerUsersDiscovery(false)
            self.remove(childCoordinator: homeCoordinator)
        }
    }
    
    private func reloadSession(clearCache: Bool) {
        self.unregisterLogoutNotification()
        self.unregisterIgnoredUsersDidChangeNotification()
        self.unregisterDidCorruptDataNotification()
        self.unregisterTrackedServerErrorNotification()
        self.cancelPendingRoomSelection()
        
        if let accounts = MXKAccountManager.shared().activeAccounts, !accounts.isEmpty {
            for account in accounts {
                account.reload(clearCache)
                
                // Replace default room summary updater
                if let eventFormatter = EventFormatter(matrixSession: account.mxSession) {
                    eventFormatter.isForSubtitle = true
                    account.mxSession.roomSummaryUpdateDelegate = eventFormatter
                }
            }
            
            if clearCache {
                // clear the media cache
                MXMediaManager.clearCache()
            }
        }
        
        if let mainSession = self.mainSession {
            self.showHome(session: mainSession)
        }
    }
    
    private func registerLogoutNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(userDidLogout), name: NSNotification.Name.legacyAppDelegateDidLogout, object: nil)
    }
    
    private func unregisterLogoutNotification() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.legacyAppDelegateDidLogout, object: nil)
    }
    
    private func registerIgnoredUsersDidChangeNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(reloadSessionAndClearCache), name: NSNotification.Name.mxSessionIgnoredUsersDidChange, object: nil)
    }
    
    private func unregisterIgnoredUsersDidChangeNotification() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.mxSessionIgnoredUsersDidChange, object: nil)
    }
    
    private func registerDidCorruptDataNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(reloadSessionAndClearCache), name: NSNotification.Name.mxSessionDidCorruptData, object: nil)
    }
    
    private func unregisterDidCorruptDataNotification() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.mxSessionDidCorruptData, object: nil)
    }
    
    private func registerTrackedServerErrorNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleTrackedServerError(notification:)), name: NSNotification.Name.mxhttpClientMatrixError, object: nil)
    }
    
    private func unregisterTrackedServerErrorNotification() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.mxhttpClientMatrixError, object: nil)
    }
    
    private func registerSessionStateNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionStateDidChange), name: NSNotification.Name.mxSessionStateDidChange, object: nil)
    }
    
    private func unregisterSessionStateNotification() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.mxSessionStateDidChange, object: nil)
    }
    
    private func postponeRoomSelection(with roomIdOrAlias: String, onEventID eventID: String? = nil) {
        self.pendingRoomIdOrAlias = roomIdOrAlias
        self.pendingEventId = eventID
        self.registerSessionStateNotification()
    }
    
    private func cancelPendingRoomSelection() {
        self.unregisterSessionStateNotification()
        self.pendingRoomIdOrAlias = nil
        self.pendingEventId = nil
    }
    
    @objc private func sessionStateDidChange() {
        // Check whether the session has at least loaded the data from the store
        if let session = self.mainSession, session.state.rawValue >= MXSessionState.storeDataReady.rawValue {
            self.unregisterSessionStateNotification()
            if let roomIdOrAlias = self.pendingRoomIdOrAlias {
                _ = showRoom(with: roomIdOrAlias, onEventID: self.pendingEventId)
            }
        }
    }
    
    private func handleRegisterAfterEmailValidation(_ registerParams: [String: String]) {
        // Check required parameters
        guard let homeserver = registerParams["hs_url"],
            let sessionId = registerParams["session_id"],
            let clientSecret = registerParams["client_secret"],
            let sid = registerParams["sid"] else {
                MXLog.debug("[AppCoordinator] handleRegisterAfterEmailValidation: failed, missing parameters")
                return
        }
        
        // Check whether there is already an active account
        if self.mainSession != nil {
            MXLog.debug("[AppCoordinator] handleRegisterAfterEmailValidation: Prompt to logout current sessions to complete the registration")
            AppDelegate.theDelegate().logout(withConfirmation: true) { (isLoggedOut) in
                if isLoggedOut {
                    self.handleRegisterAfterEmailValidation(registerParams)
                }
            }
            return
        }
        
        // Create a rest client
        self.presentActivityIndicator()
        let restClientBuilder = RestClientBuilder()
        restClientBuilder.build(fromHomeServer: homeserver) { (restClientBuilderResult) in
            switch restClientBuilderResult {
            case .success(let restClient):
                // Apply the potential id server url if any
                if let identityServerURL = registerParams["is_url"] {
                    restClient.identityServer = identityServerURL
                }
                
                guard let identityServer = restClient.identityServer,
                    let identityServerURL = URL(string: identityServer),
                    let identityServerHost = identityServerURL.host else {
                        let error = NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: TchapL10n.errorMessageDefault])
                        self.showError(error)
                        return
                }
                
                let registrationService = RegistrationService(accountManager: MXKAccountManager.shared(), restClient: restClient)
                let deviceDisplayName = UIDevice.current.name
                let threePIDCredentials = ThreePIDCredentials(clientSecret: clientSecret, sid: sid, identityServerHost: identityServerHost)
                
                registrationService.register(withEmailCredentials: threePIDCredentials, sessionId: sessionId, password: nil, deviceDisplayName: deviceDisplayName) { (registrationResult) in
                    self.registrationService = nil
                    self.removeActivityIndicator()
                    switch registrationResult {
                    case .success:
                        MXLog.debug("[AppCoordinator] handleRegisterAfterEmailValidation: success")
                        _ = self.userDidLogin()
                    case .failure(let error):
                        self.showError(error)
                    }
                }
                self.registrationService = registrationService
            case .failure(let error):
                self.removeActivityIndicator()
                self.showError(error)
            }
        }
    }
    
    private func presentActivityIndicator() {
        let rootViewController = AppDelegate.theDelegate().window.rootViewController
        
        if let view = rootViewController?.presentedViewController?.view ?? rootViewController?.view {
            self.activityIndicatorPresenter.presentActivityIndicator(on: view, animated: true)
        }
    }
    
    private func removeActivityIndicator() {
        self.activityIndicatorPresenter.removeCurrentActivityIndicator(animated: true)
    }
    
    private func showError(_ error: Error) {
        // FIXME: Present an error on coordinator.toPresentable()
        AppDelegate.theDelegate().showError(asAlert: error)
    }
    
    private func userDidLogin() -> Bool {
        let success: Bool
        
        if let mainSession = self.mainSession {
            // self.showSplitView(session: mainSession)
            self.showHome(session: mainSession)
            success = true
        } else {
            MXLog.debug("[AppCoordinator] Did not find session for current user")
            success = false
            // TODO: Present an error on
            // coordinator.toPresentable()
        }
        
        return success
    }
    
    @objc private func userDidLogout() {
        self.unregisterLogoutNotification()
        self.unregisterIgnoredUsersDidChangeNotification()
        self.unregisterDidCorruptDataNotification()
        self.unregisterTrackedServerErrorNotification()
        self.cancelPendingRoomSelection()
        
        self.showWelcome()
        
//        if let splitViewCoordinator = self.splitViewCoordinator {
//            self.remove(childCoordinator: splitViewCoordinator)
//        }
        
        self.removeHome()
    }
    
    @objc private func reloadSessionAndClearCache() {
        // Reload entirely the app
        self.reloadSession(clearCache: true)
    }
    
    @objc private func handleTrackedServerError(notification: Notification) {
        guard let error = notification.userInfo?[kMXHTTPClientMatrixErrorNotificationErrorKey] as? MXError else {
            return
        }
        if error.errcode == Constants.expiredAccountError {
            self.handleExpiredAccount()
        }
    }
    
    private func handleExpiredAccount() {
        MXLog.debug("[AppCoordinator] expired account")
        // Suspend the app by closing all the sessions (presently only one session is supported)
        if let accounts = MXKAccountManager.shared().activeAccounts, !accounts.isEmpty {
            for account in accounts {
                account.closeSession(true)
            }
        }
        // clear the media cache
        MXMediaManager.clearCache()
        
        // Remove the block provided to the contactManager to discover users
        if let homeCoordinator = self.homeCoordinator {
            homeCoordinator.overrideContactManagerUsersDiscovery(false)
        }
        
        if self.expiredAccountAlertController == nil {
            self.displayExpiredAccountAlert()
        }
    }
    
    private func displayExpiredAccountAlert() {
        guard let presenter = self.homeCoordinator?.toPresentable() else {
            return
        }
        
        self.expiredAccountAlertController?.dismiss(animated: false)
        
        let alert = UIAlertController(title: TchapL10n.warningTitle, message: TchapL10n.expiredAccountAlertMessage, preferredStyle: .alert)
        
        let resumeTitle = TchapL10n.expiredAccountResumeButton
        let resumeAction = UIAlertAction(title: resumeTitle, style: .default, handler: { action in
            // Relaunch the session
            self.reloadSession(clearCache: false)
        })
        alert.addAction(resumeAction)
        let sendEmailTitle = TchapL10n.expiredAccountRequestRenewalEmailButton
        let sendEmailAction = UIAlertAction(title: sendEmailTitle, style: .default, handler: { action in
            // Request a new email for the main account
            if let credentials = MXKAccountManager.shared().activeAccounts.first?.mxCredentials {
                let accountValidityService = AccountValidityService(credentials: credentials)
                _ = accountValidityService.requestRenewalEmail(completion: { (response) in
                    switch response {
                    case .success:
                        // Update the displayed alert
                        self.displayAlertOnRequestedRenewalEmail()
                    case .failure(let error):
                        // Display again the alert
                        self.displayExpiredAccountAlert()
                        self.showError(error)
                    }
                    self.accountValidityService = nil
                    
                })
                self.accountValidityService = accountValidityService
            }
        })
        alert.addAction(sendEmailAction)
        self.expiredAccountAlertController = alert
        
        presenter.present(alert, animated: true, completion: nil)
    }
    
    private func displayAlertOnRequestedRenewalEmail() {
        guard let presenter = self.homeCoordinator?.toPresentable() else {
            return
        }
        
        self.expiredAccountAlertController?.dismiss(animated: false)
        
        let alert = UIAlertController(title: TchapL10n.infoTitle, message: TchapL10n.expiredAccountOnNewSentEmailMsg, preferredStyle: .alert)
        
        let resumeTitle = TchapL10n.expiredAccountResumeButton
        let resumeAction = UIAlertAction(title: resumeTitle, style: .default, handler: { action in
            // Relaunch the session
            self.reloadSession(clearCache: false)
        })
        alert.addAction(resumeAction)

        self.expiredAccountAlertController = alert
        
        presenter.present(alert, animated: true, completion: nil)
    }
    
    private func presentApplicationUpdate(with versionInfo: ClientVersionInfo) {
        guard self.appVersionUpdateCoordinator == nil else {
            MXLog.debug("[AppCoordinor] AppVersionUpdateCoordinator already presented")
            return
        }
        
        // Update should be display once and has already been dislayed, do not display again
        if versionInfo.displayOnlyOnce && self.appVersionChecker.isClientVersionInfoAlreadyDisplayed(versionInfo) {
            MXLog.debug("[AppCoordinor] AppVersionUpdateCoordinator already presented for versionInfo: \(versionInfo)")
            return
        } else if versionInfo.allowOpeningApp && self.appVersionChecker.isClientVersionInfoAlreadyDisplayedToday(versionInfo) {
            MXLog.debug("[AppCoordinor] AppVersionUpdateCoordinator already presented today for versionInfo: \(versionInfo)")
            return
        }
        
        let appVersionUpdateCoordinator = AppVersionUpdateCoordinator(rootRouter: self.rootRouter, versionInfo: versionInfo)
        appVersionUpdateCoordinator.delegate = self
        appVersionUpdateCoordinator.start()
        self.add(childCoordinator: appVersionUpdateCoordinator)
        self.appVersionUpdateCoordinator = appVersionUpdateCoordinator
        
        self.appVersionCheckerStore.saveLastDisplayedClientVersionInfo(versionInfo)
        self.appVersionCheckerStore.saveLastDisplayedClientVersionDate(Calendar.current.startOfDay(for: Date()))
    }
}

// MARK: - WelcomeCoordinatorDelegate
extension AppCoordinator: WelcomeCoordinatorDelegate {
    
    func welcomeCoordinatorUserDidAuthenticate(_ coordinator: WelcomeCoordinatorType) {
        // Check that the new account actually exists before removing the current coordinator
        if userDidLogin() {
            self.remove(childCoordinator: coordinator)
        }
    }
}

// MARK: - HomeCoordinatorDelegate
extension AppCoordinator: HomeCoordinatorDelegate {
    func homeCoordinator(_ coordinator: HomeCoordinatorType, reloadMatrixSessionsByClearingCache clearCache: Bool) {
        self.reloadSession(clearCache: clearCache)
    }
    
    func homeCoordinator(_ coordinator: HomeCoordinatorType, handlePermalinkFragment fragment: String) -> Bool {
        return self.handlePermalinkFragment(fragment)
    }
}

// MARK: - AppVersionUpdateCoordinatorDelegate
extension AppCoordinator: AppVersionUpdateCoordinatorDelegate {
    func appVersionUpdateCoordinatorDidCancel(_ coordinator: AppVersionUpdateCoordinatorType) {
        self.remove(childCoordinator: coordinator)
    }
}

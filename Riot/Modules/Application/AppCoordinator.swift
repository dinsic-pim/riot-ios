/*
 Copyright 2020 New Vector Ltd
 
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
import MatrixSDK
import CommonKit
import UIKit

#if DEBUG
import FLEX
#endif

/// The AppCoordinator is responsible of screen navigation and data injection at root application level. It decides
/// if authentication or home screen should be shown and inject data needed for these flows, it changes the navigation
/// stack on deep link, displays global warning.
/// This class should avoid to contain too many data management code not related to screen navigation logic. For example
/// `MXSession` or push notification management should be handled in dedicated classes and report only navigation
/// changes to the AppCoordinator.
final class AppCoordinator: NSObject, AppCoordinatorType {
    
    // MARK: - Constants
    // Tchap: Add expired account management
    private enum Constants {
        static let expiredAccountError: String = "ORG_MATRIX_EXPIRED_ACCOUNT"
    }
    
    // MARK: - Properties
    
    private let customSchemeURLParser: CustomSchemeURLParser
  
    // MARK: Private
    
    private let rootRouter: RootRouterType
    // swiftlint:disable weak_delegate
    fileprivate let legacyAppDelegate: LegacyAppDelegate = AppDelegate.theDelegate()
    // swiftlint:enable weak_delegate
    
    private let appVersionCheckerStore: AppVersionCheckerStoreType
    private let appVersionChecker: AppVersionChecker
    private var pendingCheckAppVersionOperation: MXHTTPOperation?
    private weak var appVersionUpdateCoordinator: AppVersionUpdateCoordinatorType?
    
    private lazy var appNavigator: AppNavigatorProtocol = {
        return AppNavigator(appCoordinator: self)
    }()
    
    fileprivate weak var splitViewCoordinator: SplitViewCoordinatorType?
    fileprivate weak var sideMenuCoordinator: SideMenuCoordinatorType?
    
    private let userSessionsService: UserSessionsService
    
    // Tchap: Add expired account management
    private weak var expiredAccountAlertController: UIAlertController?
    private var accountValidityService: AccountValidityServiceType?
        
    /// Main user Matrix session
    private var mainMatrixSession: MXSession? {
        return self.userSessionsService.mainUserSession?.matrixSession
    }
        
    private var currentSpaceId: String?
  
    // MARK: Public
    
    var childCoordinators: [Coordinator] = []
    
    // MARK: - Setup
    
    init(router: RootRouterType, window: UIWindow) {
        self.rootRouter = router
        self.customSchemeURLParser = CustomSchemeURLParser()
        self.userSessionsService = UserSessionsService.shared
        
        let clientConfigurationService = ClientConfigurationService()
        let appVersionCheckerStore = AppVersionCheckerStore()
        self.appVersionChecker = AppVersionChecker(clientConfigurationService: clientConfigurationService, appVersionCheckerStore: appVersionCheckerStore)
        self.appVersionCheckerStore = appVersionCheckerStore
        
        super.init()
        
        setupFlexDebuggerOnWindow(window)
    }
    
    // MARK: - Public methods
    
    func start() {
        self.setupLogger()
        self.setupTheme()
        self.excludeAllItemsFromBackup()
        
        // Setup navigation router store
        _ = NavigationRouterStore.shared
        
        if BuildSettings.enableSideMenu {
            self.addSideMenu()
        }
        
        // NOTE: When split view is shown there can be no Matrix sessions ready. Keep this behavior or use a loading screen before showing the split view.
        self.showSplitView()
        MXLog.debug("[AppCoordinator] Showed split view")
    }
    
    func open(url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // NOTE: As said in the Apple documentation be careful on security issues with Custom Scheme URL:
        // https://developer.apple.com/documentation/xcode/allowing_apps_and_websites_to_link_to_your_content/defining_a_custom_url_scheme_for_your_app
        
        do {
            let deepLinkOption = try self.customSchemeURLParser.parse(url: url, options: options)
            return self.handleDeepLinkOption(deepLinkOption)
        } catch {
            MXLog.debug("[AppCoordinator] Custom scheme URL parsing failed with error: \(error)")
            return false
        }
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
    private func setupLogger() {
        UILog.configure(logger: MatrixSDKLogger.self)
    }
    
    private func setupTheme() {
        ThemeService.shared().themeId = RiotSettings.shared.userInterfaceTheme
        if #available(iOS 14.0, *) {
            // Set theme id from current theme.identifier, themeId can be nil.
            if let themeId = ThemeIdentifier(rawValue: ThemeService.shared().theme.identifier) {
                ThemePublisher.configure(themeId: themeId)
            } else {
                MXLog.error("[AppCoordinator] No theme id found to update ThemePublisher")
            }
            
            // Always republish theme change events, and again always getting the identifier from the theme.
            let themeIdPublisher = NotificationCenter.default.publisher(for: Notification.Name.themeServiceDidChangeTheme)
                .compactMap({ _ in ThemeIdentifier(rawValue: ThemeService.shared().theme.identifier) })
                .eraseToAnyPublisher()

            ThemePublisher.shared.republish(themeIdPublisher: themeIdPublisher)
        }
    }
    
    private func excludeAllItemsFromBackup() {
        let manager = FileManager.default
        
        // Individual files and directories created by the application or SDK are excluded case-by-case,
        // but sometimes the lifecycle of a file is not directly controlled by the app (e.g. plists for
        // UserDefaults). For that reason the app will always exclude all top-level directories as well
        // as individual files.
        manager.excludeAllUserDirectoriesFromBackup()
        manager.excludeAllAppGroupDirectoriesFromBackup()
    }
    
    private func showAuthentication() {
        // TODO: Implement
    }
    
    private func showLoading() {
        // TODO: Implement
    }
    
    private func showPinCode() {
        // TODO: Implement
    }
    
    private func showSplitView() {
        let coordinatorParameters = SplitViewCoordinatorParameters(router: self.rootRouter, userSessionsService: self.userSessionsService, appNavigator: self.appNavigator)
                        
        let splitViewCoordinator = SplitViewCoordinator(parameters: coordinatorParameters)
        splitViewCoordinator.delegate = self
        splitViewCoordinator.start()
        self.add(childCoordinator: splitViewCoordinator)
        self.splitViewCoordinator = splitViewCoordinator
        
        // Tchap: Add expired account management
        self.registerTrackedServerErrorNotification()
    }
    
    private func addSideMenu() {
        let appInfo = AppInfo.current
        let coordinatorParameters = SideMenuCoordinatorParameters(appNavigator: self.appNavigator, userSessionsService: self.userSessionsService, appInfo: appInfo)
        
        let coordinator = SideMenuCoordinator(parameters: coordinatorParameters)
        coordinator.delegate = self
        coordinator.start()
        self.add(childCoordinator: coordinator)
        self.sideMenuCoordinator = coordinator
    }
    
    private func checkAppVersion() {
        // TODO: Implement
    }
    
    private func handleDeepLinkOption(_ deepLinkOption: DeepLinkOption) -> Bool {
        
        let canOpenLink: Bool
        
        switch deepLinkOption {
        case .connect(let loginToken, let transactionId):
            canOpenLink = self.legacyAppDelegate.continueSSOLogin(withToken: loginToken, txnId: transactionId)
        }
        
        return canOpenLink
    }
    
    private func setupFlexDebuggerOnWindow(_ window: UIWindow) {
        #if DEBUG
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(showFlexDebugger))
        tapGestureRecognizer.numberOfTouchesRequired = 2
        tapGestureRecognizer.numberOfTapsRequired = 2
        window.addGestureRecognizer(tapGestureRecognizer)
        #endif
    }
    
    @objc private func showFlexDebugger() {
        #if DEBUG
        FLEXManager.shared.showExplorer()
        #endif
    }
    
    fileprivate func navigate(to destination: AppNavigatorDestination) {
        switch destination {
        case .homeSpace:
            MXLog.verbose("Switch to home space")
            self.navigateToSpace(with: nil)
            Analytics.shared.activeSpace = nil
        case .space(let spaceId):
            MXLog.verbose("Switch to space with id: \(spaceId)")
            self.navigateToSpace(with: spaceId)
            Analytics.shared.activeSpace = userSessionsService.mainUserSession?.matrixSession.spaceService.getSpace(withId: spaceId)
        }
    }
    
    private func navigateToSpace(with spaceId: String?) {
        guard spaceId != self.currentSpaceId else {
            MXLog.verbose("Space with id: \(String(describing: spaceId)) is already selected")
            return
        }
        
        self.currentSpaceId = spaceId
        
        // Reload split view with selected space id
        self.splitViewCoordinator?.start(with: spaceId)
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
    
    // Tchap: Add expired account management
    private func registerTrackedServerErrorNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleTrackedServerError(notification:)), name: NSNotification.Name.mxhttpClientMatrixError, object: nil)
    }
    
    private func unregisterTrackedServerErrorNotification() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.mxhttpClientMatrixError, object: nil)
    }
    
    private func registerLogoutNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(userDidLogout), name: NSNotification.Name.legacyAppDelegateDidLogout, object: nil)
    }
    
    private func unregisterLogoutNotification() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.legacyAppDelegateDidLogout, object: nil)
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
        NSLog("[AppCoordinator] expired account")
        // Suspend the app by closing all the sessions (presently only one session is supported)
        if let accounts = MXKAccountManager.shared().activeAccounts, !accounts.isEmpty {
            for account in accounts {
                account.closeSession(true)
            }
        }
        // clear the media cache
        MXMediaManager.clearCache()
        
        if self.expiredAccountAlertController == nil {
            self.displayExpiredAccountAlert()
        }
    }
    
    private func displayExpiredAccountAlert() {
        guard let presenter = self.splitViewCoordinator?.toPresentable() else {
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
        guard let presenter = self.splitViewCoordinator?.toPresentable() else {
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
    
    private func reloadSession(clearCache: Bool) {
        self.unregisterLogoutNotification()
        self.unregisterTrackedServerErrorNotification()
        
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
        
        self.showSplitView()
    }
    
    @objc private func userDidLogout() {
        self.unregisterLogoutNotification()
        self.unregisterTrackedServerErrorNotification()
    }
    
    private func showError(_ error: Error) {
        // FIXME: Present an error on coordinator.toPresentable()
        AppDelegate.theDelegate().showError(asAlert: error)
    }
}

// MARK: - AppVersionUpdateCoordinatorDelegate
extension AppCoordinator: AppVersionUpdateCoordinatorDelegate {
    func appVersionUpdateCoordinatorDidCancel(_ coordinator: AppVersionUpdateCoordinatorType) {
        self.remove(childCoordinator: coordinator)
    }
}

// MARK: - LegacyAppDelegateDelegate
extension AppCoordinator: LegacyAppDelegateDelegate {
    func legacyAppDelegate(_ legacyAppDelegate: LegacyAppDelegate!, wantsToPopToHomeViewControllerAnimated animated: Bool, completion: (() -> Void)!) {
        
        MXLog.debug("[AppCoordinator] wantsToPopToHomeViewControllerAnimated")
        
        self.splitViewCoordinator?.popToHome(animated: animated, completion: completion)
    }
    
    func legacyAppDelegateRestoreEmptyDetailsViewController(_ legacyAppDelegate: LegacyAppDelegate!) {
        self.splitViewCoordinator?.resetDetails(animated: false)
    }
    
    func legacyAppDelegate(_ legacyAppDelegate: LegacyAppDelegate!, didAddMatrixSession session: MXSession!) {
    }
    
    func legacyAppDelegate(_ legacyAppDelegate: LegacyAppDelegate!, didRemoveMatrixSession session: MXSession?) {
        guard let session = session else { return }
        // Handle user session removal on clear cache. On clear cache the account has his session closed but the account is not removed.
        self.userSessionsService.removeUserSession(relatedToMatrixSession: session)
    }
    
    func legacyAppDelegate(_ legacyAppDelegate: LegacyAppDelegate!, didAdd account: MXKAccount!) {
        self.userSessionsService.addUserSession(fromAccount: account)
    }
    
    func legacyAppDelegate(_ legacyAppDelegate: LegacyAppDelegate!, didRemove account: MXKAccount!) {
        self.userSessionsService.removeUserSession(relatedToAccount: account)
    }
    
    func legacyAppDelegate(_ legacyAppDelegate: LegacyAppDelegate!, didNavigateToSpaceWithId spaceId: String!) {
        self.sideMenuCoordinator?.select(spaceWithId: spaceId)
    }
}

// MARK: - SplitViewCoordinatorDelegate
extension AppCoordinator: SplitViewCoordinatorDelegate {
    func splitViewCoordinatorDidCompleteAuthentication(_ coordinator: SplitViewCoordinatorType) {
        self.legacyAppDelegate.authenticationDidComplete()
    }
}

// MARK: - SideMenuCoordinatorDelegate
extension AppCoordinator: SideMenuCoordinatorDelegate {
    func sideMenuCoordinator(_ coordinator: SideMenuCoordinatorType, didTapMenuItem menuItem: SideMenuItem, fromSourceView sourceView: UIView) {
        if menuItem == .inviteFriends {
            self.splitViewCoordinator?.presentInvitePeople()
        }
    }
}

// MARK: - AppNavigator

// swiftlint:disable private_over_fileprivate
fileprivate class AppNavigator: AppNavigatorProtocol {
// swiftlint:enable private_over_fileprivate
    
    // MARK: - Properties
    
    private unowned let appCoordinator: AppCoordinator
    
    lazy var sideMenu: SideMenuPresentable = {
        guard let sideMenuCoordinator = appCoordinator.sideMenuCoordinator else {
            fatalError("sideMenuCoordinator is not initialized")
        }
        
        return SideMenuPresenter(sideMenuCoordinator: sideMenuCoordinator)
    }()

    // MARK: - Setup
    
    init(appCoordinator: AppCoordinator) {
        self.appCoordinator = appCoordinator
    }
    
    // MARK: - Public
    
    func navigate(to destination: AppNavigatorDestination) {
        self.appCoordinator.navigate(to: destination)
    }
}

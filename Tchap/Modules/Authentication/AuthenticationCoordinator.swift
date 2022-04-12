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

protocol AuthenticationCoordinatorDelegate: AnyObject {
    func authenticationCoordinator(coordinator: AuthenticationCoordinatorType, didAuthenticateWithUserId userId: String)
}

final class AuthenticationCoordinator: AuthenticationCoordinatorType {
    
    // MARK: - Properties
    
    // MARK: Private
    
    private let authenticationViewController: AuthenticationViewController
    private let navigationRouter: NavigationRouterType
    private let authenticationService: AuthenticationServiceType
    private let activityIndicatorPresenter: ActivityIndicatorPresenterType
    private let authenticationErrorPresenter: ErrorPresenter
    
    // MARK: Public
    
    weak var delegate: AuthenticationCoordinatorDelegate?
    
    var childCoordinators: [Coordinator] = []
    
    // MARK: - Setup
    
    init(router: NavigationRouterType) {
        self.navigationRouter = router
        self.authenticationService = AuthenticationService(accountManager: MXKAccountManager.shared())
        let authenticationViewModel = AuthenticationViewModel()
        let authenticationViewController = AuthenticationViewController.instantiate(viewModel: authenticationViewModel)
        authenticationViewController.vc_removeBackTitle()
        self.authenticationViewController = authenticationViewController
        self.activityIndicatorPresenter = ActivityIndicatorPresenter()
        self.authenticationErrorPresenter = AlertErrorPresenter(viewControllerPresenter: authenticationViewController)
    }
    
    // MARK: - Public methods
    
    func start() {
        self.registerLoginNotification()
        self.authenticationViewController.delegate = self
    }
    
    func toPresentable() -> UIViewController {
        return self.authenticationViewController
    }
    
    // MARK: - Private methods
    
    private func registerLoginNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(userDidLogin), name: UserSessionsService.didAddUserSession, object: nil)
    }
    
    private func unregisterLoginNotification() {
        NotificationCenter.default.removeObserver(self, name: UserSessionsService.didAddUserSession, object: nil)
    }
    
    @objc private func userDidLogin() {
        self.unregisterLoginNotification()
        
        if let userId = MXKAccountManager.shared().accounts.last?.mxCredentials.userId {
            self.didAuthenticate(with: userId)
        }
    }
    
    private func didAuthenticate(with userId: String) {
        self.delegate?.authenticationCoordinator(coordinator: self, didAuthenticateWithUserId: userId)
    }
    
    private func authenticate(with mail: String, password: String) {
        self.authenticationViewController.setUserInteraction(enabled: false)
        self.activityIndicatorPresenter.presentActivityIndicator(on: self.authenticationViewController.view, animated: true)
        
        self.authenticationService.authenticate(with: mail, password: password) { (response) in                        
            
            self.activityIndicatorPresenter.removeCurrentActivityIndicator(animated: true)
            self.authenticationViewController.setUserInteraction(enabled: true)
            
            switch response {
            case .success:
                // NOTE: Do not call delegate directly for the moment, wait for NSNotification.Name.legacyAppDelegateDidLogin
                MXLog.debug("[AuthenticationCoordinator] User did authenticate with success")
            case .failure(let error):
                // Display error on AuthenticationViewController
                let authenticationErrorPresentableMaker = AuthenticationErrorPresentableMaker()
                if let errorPresentable = authenticationErrorPresentableMaker.errorPresentable(from: error) {
                    self.authenticationErrorPresenter.present(errorPresentable: errorPresentable)
                }
            }
        }
    }
    
    private func showForgotPassword() {
        let forgotPasswordCoordinator = ForgotPasswordCoordinator(router: self.navigationRouter)
        forgotPasswordCoordinator.start()
        forgotPasswordCoordinator.delegate = self
        
        self.add(childCoordinator: forgotPasswordCoordinator)
        
        self.navigationRouter.push(forgotPasswordCoordinator, animated: true) { [weak self] in
            self?.remove(childCoordinator: forgotPasswordCoordinator)
        }
    }
}

// MARK: - AuthenticationViewControllerDelegate
extension AuthenticationCoordinator: AuthenticationViewControllerDelegate {
    
    func authenticationViewController(_ authenticationViewController: AuthenticationViewController, didTapNextButtonWith mail: String, password: String) {
        self.authenticate(with: mail, password: password)
    }
    
    func authenticationViewControllerDidTapForgotPasswordButton(_ authenticationViewController: AuthenticationViewController) {
        self.showForgotPassword()
    }
}

// MARK: - ForgotPasswordCoordinatorDelegate
extension AuthenticationCoordinator: ForgotPasswordCoordinatorDelegate {
    func forgotPasswordCoordinatorDidComplete(_ forgotPasswordCoordinator: ForgotPasswordCoordinator) {
        self.navigationRouter.popToModule(self.authenticationViewController, animated: true)
    }
}

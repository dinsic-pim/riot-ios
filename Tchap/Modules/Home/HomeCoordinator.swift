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

protocol HomeCoordinatorDelegate: AnyObject {
    func homeCoordinator(_ coordinator: HomeCoordinatorType, reloadMatrixSessionsByClearingCache clearCache: Bool)
    func homeCoordinator(_ coordinator: HomeCoordinatorType, handlePermalinkFragment fragment: String) -> Bool
}

final class HomeCoordinator: NSObject, HomeCoordinatorType {
    
    // MARK: - Properties
    
    // MARK: Private
    
    private let navigationRouter: NavigationRouterType
    private let session: MXSession
    private let inviteService: InviteServiceType
    private let thirdPartyIDResolver: ThirdPartyIDResolverType
    private let identityServer: String
    
    private weak var homeViewController: HomeViewController?
    private weak var roomsCoordinator: RoomsCoordinatorType?
    private weak var contactsCoordinator: ContactsCoordinatorType?
    
    private let activityIndicatorPresenter: ActivityIndicatorPresenterType
    
    private var errorPresenter: ErrorPresenter?
    private weak var currentAlertController: UIAlertController?
    
    // MARK: Public
    
    // MARK: Public
    
    var childCoordinators: [Coordinator] = []
    
    weak var delegate: HomeCoordinatorDelegate?
    
    // MARK: - Setup
    
    init(session: MXSession) {
        // Setup navigation router store
        _ = NavigationRouterStore.shared
        
        self.navigationRouter = NavigationRouter(navigationController: RiotNavigationController())
        self.session = session
        self.inviteService = InviteService(session: self.session)
        self.thirdPartyIDResolver = ThirdPartyIDResolver(session: session)
        self.identityServer = session.matrixRestClient.identityServer ?? session.matrixRestClient.homeserver
        self.activityIndicatorPresenter = ActivityIndicatorPresenter()
    }
    
    // MARK: - Public methods
    
    func start() {
        let roomsCoordinator = RoomsCoordinator(router: self.navigationRouter, session: self.session)
        let contactsCoordinator = ContactsCoordinator(router: self.navigationRouter, session: self.session)
        
        roomsCoordinator.delegate = self
        contactsCoordinator.delegate = self
        
        self.add(childCoordinator: roomsCoordinator)
        self.add(childCoordinator: contactsCoordinator)
        
        let viewControllers = [roomsCoordinator.toPresentable(), contactsCoordinator.toPresentable()]
        let viewControllersTitles = [TchapL10n.conversationsTabTitle, TchapL10n.contactsTabTitle]
        
        let globalSearchBar = GlobalSearchBar.instantiate()
        globalSearchBar.delegate = self
        
        let segmentedViewController = self.createHomeViewController(with: viewControllers, viewControllersTitles: viewControllersTitles, globalSearchBar: globalSearchBar)
        segmentedViewController.vc_removeBackTitle()
        segmentedViewController.delegate = self
        
        self.navigationRouter.setRootModule(segmentedViewController)
        
        roomsCoordinator.start()
        contactsCoordinator.start()
        
        self.roomsCoordinator = roomsCoordinator
        self.contactsCoordinator = contactsCoordinator
        self.homeViewController = segmentedViewController
        self.errorPresenter = AlertErrorPresenter(viewControllerPresenter: segmentedViewController)
    }
    
    func toPresentable() -> UIViewController {
        return self.navigationRouter.toPresentable()
    }
    
    func showRoom(with roomID: String, onEventID eventID: String? = nil) {
        AppDelegate.theDelegate().removeDeliveredNotifications(withRoomId: roomID, completion: nil)
        
        self.navigationRouter.popToRootModule(animated: false)
        
        let parameters = RoomCoordinatorParameters(navigationRouter: self.navigationRouter,
                                                   navigationRouterStore: NavigationRouterStore.shared,
                                                   session: self.session,
                                                   roomId: roomID,
                                                   eventId: eventID)
        let roomCoordinator = RoomCoordinator(parameters: parameters)
        roomCoordinator.start()
        roomCoordinator.delegate = self
        
        self.add(childCoordinator: roomCoordinator)
        self.navigationRouter.push(roomCoordinator, animated: true) {
            self.remove(childCoordinator: roomCoordinator)
        }
    }
    
    func showRoomPreview(with roomIdOrAlias: String, roomName: String?, onEventID eventID: String? = nil) {
        if roomIdOrAlias.hasPrefix("#") {
            self.session.matrixRestClient.roomId(forRoomAlias: roomIdOrAlias) { [weak self] (response) in
                guard let sself = self else {
                    return
                }
                
                switch response {
                case .success(let roomId):
                    let roomPreviewData: RoomPreviewData = RoomPreviewData(roomId: roomId, roomAlias: roomIdOrAlias, andSession: sself.session)
                    roomPreviewData.roomName = roomName != nil ? roomName : roomIdOrAlias
                    
                    sself.showRoomPreview(with: roomPreviewData, onEventID: eventID)
                case .failure(let error):
                    let errorMessage: String
                    
                    if MXError(nsError: error).errcode == kMXErrCodeStringNotFound {
                        errorMessage = TchapL10n.tchapRoomInvalidLink
                    } else {
                        errorMessage = TchapL10n.errorMessageDefault
                    }
                    
                    let errorPresentable = ErrorPresentableImpl(title: TchapL10n.errorTitleDefault, message: errorMessage)
                    sself.errorPresenter?.present(errorPresentable: errorPresentable)
                }
            }
        } else {
            let roomPreviewData: RoomPreviewData = RoomPreviewData(roomId: roomIdOrAlias, roomAlias: nil, andSession: self.session)
            roomPreviewData.roomName = roomName != nil ? roomName : roomIdOrAlias
            
            self.showRoomPreview(with: roomPreviewData, onEventID: eventID)
        }
    }
    
    func showRoomPreview(with publicRoom: MXPublicRoom) {
        let roomPreviewCoordinator = RoomPreviewCoordinator(session: self.session, publicRoom: publicRoom)
        showRoomPreview(with: roomPreviewCoordinator)
    }
    
    func showRoomPreview(with roomPreviewData: RoomPreviewData, onEventID eventID: String? = nil) {
        let roomPreviewCoordinator = RoomPreviewCoordinator(session: self.session, roomPreviewData: roomPreviewData)
        showRoomPreview(with: roomPreviewCoordinator)
    }
    
    func showRoomPreview(with coordinator: RoomPreviewCoordinator) {
        let roomPreviewCoordinator = coordinator
        roomPreviewCoordinator.start()
        roomPreviewCoordinator.delegate = self
        
        self.add(childCoordinator: roomPreviewCoordinator)
        
        self.navigationRouter.push(roomPreviewCoordinator, animated: true) { [weak self] in
            self?.remove(childCoordinator: roomPreviewCoordinator)
        }
    }
    
    func scrollToRoom(with roomID: String, animated: Bool) {
        self.homeViewController?.setSelectedTabIndex(0)
        self.roomsCoordinator?.scrollToRoom(with: roomID, animated: animated)
    }
    
    func overrideContactManagerUsersDiscovery(_ isOverridden: Bool) {
        if isOverridden {
            MXKContactManager.shared().discoverUsersBoundTo3PIDsBlock = { [weak self] (threepids: [[String]], success: @escaping (([[String]]) -> Void), failure: @escaping ((Error) -> Void)) in
                guard let self = self else {
                    return
                }
                
                _ = self.thirdPartyIDResolver.bulkLookup(threepids: threepids,
                                                         identityServer: self.identityServer,
                                                         success: success,
                                                         failure: failure)
            }
        } else {
            // Remove the block provided to the contactManager to discover users
            MXKContactManager.shared().discoverUsersBoundTo3PIDsBlock = nil
        }
    }
    
    // MARK: - Private methods
    
    private func registerSessionStateNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionStateDidChange), name: NSNotification.Name.mxSessionStateDidChange, object: nil)
    }
    
    private func unregisterSessionStateNotification() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.mxSessionStateDidChange, object: nil)
    }
    
    @objc private func sessionStateDidChange() {
        // Check whether the current user id is available
        if let myUserId = self.session.myUser?.userId {
            self.unregisterSessionStateNotification()
            self.homeViewController?.setExternalUseMode(UserService.isExternalUser(for: myUserId))
        }
    }
    
    private func showSettings(animated: Bool) {
        let settingsCoordinator = SettingsCoordinator(router: self.navigationRouter)
        settingsCoordinator.start()
        settingsCoordinator.delegate = self
        
        self.add(childCoordinator: settingsCoordinator)
        self.navigationRouter.push(settingsCoordinator, animated: animated) {
            self.remove(childCoordinator: settingsCoordinator)
        }
    }
    
    private func showFavourites(animated: Bool) {
        let favouriteMessagesCoordinator = FavouriteMessagesCoordinator(session: self.session)
        favouriteMessagesCoordinator.start()
        favouriteMessagesCoordinator.delegate = self
        
        self.add(childCoordinator: favouriteMessagesCoordinator)
        self.navigationRouter.push(favouriteMessagesCoordinator, animated: animated) {
            self.remove(childCoordinator: favouriteMessagesCoordinator)
        }
    }

    private func createHomeViewController(with viewControllers: [UIViewController], viewControllersTitles: [String], globalSearchBar: GlobalSearchBar) -> HomeViewController {
        let homeViewController = HomeViewController.instantiate(with: viewControllers, viewControllersTitles: viewControllersTitles, globalSearchBar: globalSearchBar)
        
        // Check whether the current user is available
        if let myUserId = self.session.myUser?.userId {
            homeViewController.setExternalUseMode(UserService.isExternalUser(for: myUserId))
        } else {
            registerSessionStateNotification()
        }
        
        homeViewController.navigationItem.leftBarButtonItem = MXKBarButtonItem(image: #imageLiteral(resourceName: "settings_icon"), style: .plain, action: { [weak self] in
            guard let sself = self else {
                return
            }
            sself.showSettings(animated: true)
        })
        
        homeViewController.navigationItem.rightBarButtonItem = MXKBarButtonItem(image: #imageLiteral(resourceName: "icon_page_favoris"), style: .plain, action: { [weak self] in
            guard let sself = self else {
                return
            }
            sself.showFavourites(animated: true)
        })
        
        return homeViewController
    }
    
    private func showPublicRooms() {
        let publicRoomServers = BuildSettings.publicRoomsDirectoryServers
        let publicRoomService = PublicRoomService(homeServersStringURL: publicRoomServers, session: self.session)
        let dataSource = PublicRoomsDataSource(session: self.session,
                                               publicRoomService: publicRoomService)
        let publicRoomsViewController = PublicRoomsViewController.instantiate(dataSource: dataSource)
        publicRoomsViewController.delegate = self
        let router = NavigationRouter(navigationController: RiotNavigationController())
        router.setRootModule(publicRoomsViewController.toPresentable())
        self.navigationRouter.present(router, animated: true)
    }
    
    // Prepare a new discussion with a user without associated room
    private func startDiscussion(with userID: String) {
        AppDelegate.theDelegate().startDirectChat(withUserId: userID, completion: nil)
    }
    
    private func showCreateNewDiscussion() {
        let createNewDiscussionCoordinator = CreateNewDiscussionCoordinator(session: self.session)
        createNewDiscussionCoordinator.delegate = self
        createNewDiscussionCoordinator.start()
        
        self.navigationRouter.present(createNewDiscussionCoordinator, animated: true)
        
        self.add(childCoordinator: createNewDiscussionCoordinator)
    }
    
    private func showCreateNewRoom() {
        let roomCreationCoordinator = RoomCreationCoordinator(session: self.session)
        roomCreationCoordinator.delegate = self
        roomCreationCoordinator.start()
        
        self.navigationRouter.present(roomCreationCoordinator, animated: true)
        
        self.add(childCoordinator: roomCreationCoordinator)
    }
    
    private func sendEmailInvite(to email: String) {
        guard let homeViewController = self.homeViewController else {
            return
        }
        
        self.activityIndicatorPresenter.presentActivityIndicator(on: homeViewController.view, animated: true)
        self.inviteService.sendEmailInvite(to: email) { [weak self] (response) in
            guard let sself = self else {
                return
            }
            
            sself.activityIndicatorPresenter.removeCurrentActivityIndicator(animated: true)
            switch response {
            case .success(let result):
                var message: String
                var discoveredUserID: String?
                switch result {
                case .inviteHasBeenSent(roomID: _):
                    message = TchapL10n.inviteSendingSucceeded
                case .inviteAlreadySent(roomID: _):
                    message = TchapL10n.inviteAlreadySentByEmail(email)
                case .inviteIgnoredForDiscoveredUser(userID: let userID):
                    discoveredUserID = userID
                    message = TchapL10n.inviteNotSentForDiscoveredUser
                case .inviteIgnoredForUnauthorizedEmail:
                    message = TchapL10n.inviteNotSentForUnauthorizedEmail(email)
                }
                
                sself.currentAlertController?.dismiss(animated: false)
                
                let alert = UIAlertController(title: TchapL10n.inviteInformationTitle, message: message, preferredStyle: .alert)
                
                let okTitle = Bundle.mxk_localizedString(forKey: "ok")
                let okAction = UIAlertAction(title: okTitle, style: .default, handler: { action in
                    if let userID = discoveredUserID {
                        // Open the discussion
                        sself.startDiscussion(with: userID)
                    }
                })
                alert.addAction(okAction)
                sself.currentAlertController = alert
                
                homeViewController.present(alert, animated: true, completion: nil)
            case .failure(let error):
                let errorPresentable = sself.inviteErrorPresentable(from: error)
                sself.errorPresenter?.present(errorPresentable: errorPresentable, animated: true)
            }
        }
        
    }
    
    private func inviteErrorPresentable(from error: Error) -> ErrorPresentable {
        let errorTitle = TchapL10n.inviteSendingFailedTitle
        let errorMessage: String
        
        let nsError = error as NSError
        
        if let message = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
            errorMessage = message
        } else {
            errorMessage = TchapL10n.errorMessageDefault
        }
        
        return ErrorPresentableImpl(title: errorTitle, message: errorMessage)
    }
}

// MARK: - SettingsCoordinatorDelegate
extension HomeCoordinator: SettingsCoordinatorDelegate {
    func settingsCoordinator(_ coordinator: SettingsCoordinatorType, reloadMatrixSessionsByClearingCache clearCache: Bool) {
        self.navigationRouter.popToRootModule(animated: false)
        self.delegate?.homeCoordinator(self, reloadMatrixSessionsByClearingCache: clearCache)
    }
}

// MARK: - GlobalSearchBarDelegate
extension HomeCoordinator: GlobalSearchBarDelegate {
    func globalSearchBar(_ globalSearchBar: GlobalSearchBar, textDidChange searchText: String?) {
        self.roomsCoordinator?.updateSearchText(searchText)
        self.contactsCoordinator?.updateSearchText(searchText)
    }
}

// MARK: - RoomsCoordinatorDelegate
extension HomeCoordinator: RoomsCoordinatorDelegate {
    func roomsCoordinator(_ coordinator: RoomsCoordinatorType, didSelectRoomID roomID: String) {
        self.showRoom(with: roomID)
    }
}

// MARK: - ContactsCoordinatorDelegate
extension HomeCoordinator: ContactsCoordinatorDelegate {
    func contactsCoordinator(_ coordinator: ContactsCoordinatorType, didSelectUserID userID: String) {
        self.startDiscussion(with: userID)
    }
    func contactsCoordinator(_ coordinator: ContactsCoordinatorType, sendEmailInviteTo email: String) {
        self.sendEmailInvite(to: email)
    }
}

// MARK: - RoomCoordinatorDelegate
extension HomeCoordinator: RoomCoordinatorDelegate {
    func roomCoordinatorDidLeaveRoom(_ coordinator: RoomCoordinatorProtocol) {
        self.navigationRouter.popToRootModule(animated: true)
    }
    
    func roomCoordinatorDidCancelRoomPreview(_ coordinator: RoomCoordinatorProtocol) {
        //
    }
    
    func roomCoordinator(_ coordinator: RoomCoordinatorProtocol, didSelectRoomWithId roomId: String) {
        //
    }
    
    func roomCoordinatorDidDismissInteractively(_ coordinator: RoomCoordinatorProtocol) {
        //
    }
    
    func roomCoordinator(_ coordinator: RoomCoordinatorType, didSelectRoomID roomID: String) {
        self.showRoom(with: roomID)
    }
    
    func roomCoordinator(_ coordinator: RoomCoordinatorType, didSelectUserID userID: String) {
        self.startDiscussion(with: userID)
    }
    
    func roomCoordinator(_ coordinator: RoomCoordinatorType, handlePermalinkFragment fragment: String) -> Bool {
        guard let delegate = self.delegate else {
            return false
        }
        return delegate.homeCoordinator(self, handlePermalinkFragment: fragment)
    }
    
    func roomCoordinator(_ coordinator: RoomCoordinatorProtocol, didSelectRoomWithId roomId: String, eventId: String?) {
        //
    }
}

// MARK: - PublicRoomsViewControllerDelegate
extension HomeCoordinator: PublicRoomsViewControllerDelegate {
    func publicRoomsViewController(_ publicRoomsViewController: PublicRoomsViewController, didSelect publicRoom: MXPublicRoom) {
        publicRoomsViewController.navigationController?.dismiss(animated: true, completion: { [weak self] in
            
            guard let roomID = publicRoom.roomId else {
                return
            }
            
            if let room: MXRoom = self?.session.room(withRoomId: roomID),
               room.summary.membership == .join {
                self?.showRoom(with: roomID)
            } else {
                // Try to preview the unknown room.
                self?.showRoomPreview(with: publicRoom)
            }
        })
    }
}
        
// MARK: - HomeViewControllerDelegate
extension HomeCoordinator: HomeViewControllerDelegate {
    
    func homeViewControllerDidTapStartChatButton(_ homeViewController: HomeViewController) {
        self.showCreateNewDiscussion()
    }
    
    func homeViewControllerDidTapCreateRoomButton(_ homeViewController: HomeViewController) {
        self.showCreateNewRoom()
    }
    
    func homeViewControllerDidTapPublicRoomsAccessButton(_ homeViewController: HomeViewController) {
        self.showPublicRooms()
    }
}

// MARK: - CreateNewDiscussionCoordinatorDelegate
extension HomeCoordinator: CreateNewDiscussionCoordinatorDelegate {
    
    func createNewDiscussionCoordinator(_ coordinator: CreateNewDiscussionCoordinatorType, didSelectUserID userID: String) {
        self.navigationRouter.dismissModule(animated: true) { [weak self] in
            self?.startDiscussion(with: userID)
            self?.remove(childCoordinator: coordinator)
        }
    }
    
    func createNewDiscussionCoordinatorDidCancel(_ coordinator: CreateNewDiscussionCoordinatorType) {
        self.navigationRouter.dismissModule(animated: true) { [weak self] in
            self?.remove(childCoordinator: coordinator)
        }
    }
}

// MARK: - RoomCreationCoordinatorDelegate
extension HomeCoordinator: RoomCreationCoordinatorDelegate {
    
    func roomCreationCoordinatorDidCancel(_ coordinator: RoomCreationCoordinatorType) {
        self.navigationRouter.dismissModule(animated: true) { [weak self] in
            self?.remove(childCoordinator: coordinator)
        }
    }
    
    func roomCreationCoordinator(_ coordinator: RoomCreationCoordinatorType, didCreateRoomWithID roomID: String) {
        self.navigationRouter.dismissModule(animated: true) { [weak self] in
            self?.remove(childCoordinator: coordinator)
            self?.showRoom(with: roomID)
        }
    }
}

// MARK: - RoomPreviewCoordinatorDelegate
extension HomeCoordinator: RoomPreviewCoordinatorDelegate {
    
    func roomPreviewCoordinatorDidCancel(_ coordinator: RoomPreviewCoordinatorType) {
        self.navigationRouter.popModule(animated: true)
    }
    
    func roomPreviewCoordinator(_ coordinator: RoomPreviewCoordinatorType, didJoinRoomWithId roomID: String, onEventId eventId: String?) {
        self.navigationRouter.popModule(animated: true)
        self.showRoom(with: roomID, onEventID: eventId)
    }
}

// MARK: - FavouriteMessagesCoordinatorDelegate
extension HomeCoordinator: FavouriteMessagesCoordinatorDelegate {
    func favouriteMessagesCoordinatorDidCancel(_ coordinator: FavouriteMessagesCoordinatorType) {
        self.navigationRouter.popModule(animated: true)
    }
    
    func favouriteMessagesCoordinator(_ coordinator: FavouriteMessagesCoordinatorType, didShowRoomWithId roomId: String, onEventId eventId: String) {
        self.navigationRouter.popModule(animated: true)
        self.showRoom(with: roomId, onEventID: eventId)
    }
    
    func favouriteMessagesCoordinator(_ coordinator: FavouriteMessagesCoordinatorType, handlePermalinkFragment fragment: String) -> Bool {
        guard let delegate = self.delegate else {
            return false
        }
        return delegate.homeCoordinator(self, handlePermalinkFragment: fragment)
    }
}

/*
 Copyright 2019 New Vector Ltd
 
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

enum InviteServiceError: Error {
    case unknown
}

/// `InviteService` is used to invite someone to join Tchap
final class InviteService: InviteServiceType {
    
    // MARK: Private
    private let session: MXSession
    
    private let discussionFinder: DiscussionFinderType
    private let thirdPartyIDResolver: ThirdPartyIDResolverType
    private let thirdPartyIDPlatformInfoResolver: ThirdPartyIDPlatformInfoResolverType
    private let roomService: RoomServiceType
    
    // MARK: - Public
    init(session: MXSession) {
        guard let serverUrlPrefix = UserDefaults.standard.string(forKey: "serverUrlPrefix") else {
            fatalError("serverUrlPrefix should be defined")
        }
        self.session = session
        self.discussionFinder = DiscussionFinder(session: session)
        self.thirdPartyIDResolver = ThirdPartyIDResolver(credentials: self.session.matrixRestClient.credentials)
        let identityServerURLs = IdentityServersURLGetter(currentIdentityServerURL: session.matrixRestClient.identityServer).identityServerUrls
        self.thirdPartyIDPlatformInfoResolver = ThirdPartyIDPlatformInfoResolver(identityServerUrls: identityServerURLs, serverPrefixURL: serverUrlPrefix)
        self.roomService = RoomService(session: session)
    }
    
    func sendEmailInvite(to email: String, completion: @escaping (MXResponse<InviteServiceResult>) -> Void) {
        // Check whether an invite has been already sent
        self.discussionFinder.getDiscussionIdentifier(for: email) { [weak self] (response) in
            guard let sself = self else {
                return
            }
            
            switch response {
            case .success(let result):
                switch result {
                case .joinedDiscussion(let roomID):
                    // There is already a discussion with this email
                    completion(.success(.inviteAlreadySent(roomID: roomID)))
                case .noDiscussion:
                    // Pursue the invite process by checking whether a Tchap account has been created for this email.
                    sself.discoverUser(with: email, completion: { [weak sself] (response) in
                        switch response {
                        case .success(let result):
                            switch result {
                            case .bound(let userID):
                                completion(.success(.inviteIgnoredForDiscoveredUser(userID: userID)))
                            case .unbound:
                                sself?.createDiscussion(with: email, completion: completion)
                            }
                        case .failure(let error):
                            completion(MXResponse.failure(error))
                        }
                    })
                default:
                    break
                }
            case .failure(let error):
                NSLog("[InviteService] sendEmailInvite failed")
                completion(MXResponse.failure(error))
            }
        }
    }
    
    // MARK: - Private
    
    // Check whether a Tchap account has been created for this email. The closure returns a nil identifier when no account exists.
    private func discoverUser(with email: String, completion: @escaping (MXResponse<ThirdPartyIDResolveResult>) -> Void) {
        if let lookup3pidsOperation = self.thirdPartyIDResolver.lookup(address: email, medium: .email, identityServer: self.session.matrixRestClient.identityServer, completion: completion) {
            lookup3pidsOperation.maxRetriesTime = 0
        } else {
            NSLog("[InviteService] discoverUser failed")
            completion(MXResponse.failure(InviteServiceError.unknown))
        }
    }
    
    private func createDiscussion(with email: String, completion: @escaping (MXResponse<InviteServiceResult>) -> Void) {
        self.isAuthorized(email: email) { [weak self] (response) in
            switch response {
            case .success(let isAuthorized):
                if isAuthorized {
                    guard let identityServer = self?.session.matrixRestClient.identityServer,
                        let identityServerURL = URL(string: identityServer),
                        let identityServerHost = identityServerURL.host else {
                        return
                    }
                    
                    let thirdPartyId = MXInvite3PID()
                    thirdPartyId.medium = MX3PID.Medium.email.identifier
                    thirdPartyId.address = email
                    thirdPartyId.identityServer = identityServerHost
                    
                    _ = self?.roomService.createDiscussionWithThirdPartyID(thirdPartyId, completion: { (response) in
                        switch response {
                        case .success(let roomID):
                            completion(.success(.inviteHasBeenSent(roomID: roomID)))
                        case .failure(let error):
                            NSLog("[InviteService] createDiscussion failed")
                            completion(MXResponse.failure(error))
                        }
                    })
                } else {
                    completion(.success(.inviteIgnoredForUnauthorizedEmail))
                }
                
            case .failure(let error):
                completion(MXResponse.failure(error))
            }
        }
    }
    
    private func isAuthorized(email: String, completion: @escaping (MXResponse<Bool>) -> Void) {
        self.thirdPartyIDPlatformInfoResolver.resolvePlatformInformation(address: email, medium: kMX3PIDMediumEmail, success: { (resolveResult) in
            switch resolveResult {
            case .authorizedThirdPartyID(info: _):
                completion(.success(true))
            case .unauthorizedThirdPartyID:
                completion(.success(false))
            }
        }, failure: { (error) in
            NSLog("[InviteService] isAuthorized failed")
            if let error = error {
                completion(MXResponse.failure(error))
            }
        })
    }
}

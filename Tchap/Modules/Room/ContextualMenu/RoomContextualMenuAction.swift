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

@objc enum RoomContextualMenuAction: Int {
    case copy
    case reply
#if ENABLE_EDITION
    case edit
#else
    case redact
#endif
    case favourite
    case share
    case more
    case resend
    case delete
    
    // MARK: - Properties
    
    var title: String {
        let title: String
        
        switch self {
        case .copy:
            title = VectorL10n.roomEventActionCopy
        case .reply:
            title = VectorL10n.roomEventActionReply
#if ENABLE_EDITION
        case .edit:
            title = VectorL10n.roomEventActionEdit
#else
        case .redact:
            title = VectorL10n.roomEventActionRedact
#endif
        case .favourite:
            title = TchapL10n.roomEventActionFavourite
        case .share:
            title = VectorL10n.roomEventActionShare
        case .more:
            title = VectorL10n.roomEventActionMore
        case .resend:
            title = VectorL10n.retry
        case .delete:
            title = VectorL10n.roomEventActionDelete
        }
        
        return title
    }
    
    var image: UIImage? {
        let image: UIImage?
        
        switch self {
        case .copy:
            image = Asset.Images_tchap.roomContextMenuCopy.image
        case .reply:
            image = Asset.Images_tchap.roomContextMenuReply.image
#if ENABLE_EDITION
        case .edit:
            image = Asset.Images_tchap.roomContextMenuEdit.image
#else
        case .redact:
            image = Asset.Images.roomContextMenuRedact.image
#endif
        case .favourite:
            image = Asset.Images_tchap.roomContextMenuFav.image
        case .share:
            image = Asset.Images_tchap.roomContextMenuShare.image
        case .more:
            image = Asset.Images_tchap.roomContextMenuMore.image
        case .resend:
            image = Asset.Images_tchap.roomContextMenuRetry.image
        case .delete:
            image = Asset.Images_tchap.roomContextMenuDelete.image
        default:
            image = nil
        }
        
        return image
    }
}

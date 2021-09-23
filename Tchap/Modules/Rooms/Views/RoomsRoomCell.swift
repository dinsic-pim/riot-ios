/*
 Copyright 2018 Vector Creations Ltd
 
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

import UIKit

class RoomsRoomCell: RoomsCell {
    // MARK: - Constants
    
    private enum Constants {
        static let hexagonImageBorderWidthDefault: CGFloat = 1.0
        static let hexagonImageBorderWidthUnrestricted: CGFloat = 5.0
    }
    
    @IBOutlet private weak var roomCategory: UILabel!
    @IBOutlet private weak var lastEventSenderName: UILabel!
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.updateAvatarView()
    }
    
    override func render(_ cellData: MXKCellData!) {
        super.render(cellData)
        
        self.lastEventSenderName.text = nil
        self.roomCategory.isHidden = true
        
        guard let session = self.roomCellData?.recentsDataSource?.mxSession, session.matrixRestClient != nil else {
            return
        }
        
        // Adjust last sender name
        if let senderId = self.roomCellData?.roomSummary?.lastMessage?.sender {
            // Try to find user in local session
            let senderUser: User
            let userService = UserService(session: session)
            
            if let userFromSession = userService.getUserFromLocalSession(with: senderId) {
                senderUser = userFromSession
            } else {
                senderUser = userService.buildTemporaryUser(from: senderId)
            }
            let displayNameComponents = DisplayNameComponents(displayName: senderUser.displayName)
            self.lastEventSenderName.text = displayNameComponents.name
        }
        
        if let category = self.roomCellData?.roomSummary.tc_roomCategory() {
            switch category {
            case .restrictedPrivateRoom:
                self.roomCategory.text = TchapL10n.roomCategoryPrivateRoom
                self.roomCategory.textColor = kColorCoral
                self.roomCategory.isHidden = false
            case .unrestrictedPrivateRoom:
                self.roomCategory.text = TchapL10n.roomCategoryExternRoom
                self.roomCategory.textColor = kColorPumpkinOrange
                self.roomCategory.isHidden = false
            case .forum:
                self.roomCategory.text = TchapL10n.roomCategoryForumRoom
                self.roomCategory.textColor = kColorJadeGreen
                self.roomCategory.isHidden = false
            default:
                break
            }
        }
        
        // Set the right avatar border
        self.updateAvatarView()
    }
    
    override func updateTheme() {
        super.updateTheme()
        self.lastEventSenderName.textColor = ThemeService.shared().theme.textPrimaryColor
    }
    
    private func updateAvatarView () {
        let avatarBorderColor: UIColor
        let avatarBorderWidth: CGFloat
        
        // Set the right avatar border
        if let accessRule = self.roomCellData?.roomSummary.tc_roomAccessRule() {
            switch accessRule {
            case .restricted:
                avatarBorderColor = kColorDarkBlue
                avatarBorderWidth = Constants.hexagonImageBorderWidthDefault
            case .unrestricted:
                avatarBorderColor = kColorDarkGrey
                avatarBorderWidth = Constants.hexagonImageBorderWidthUnrestricted
            default:
                avatarBorderColor = UIColor.clear
                avatarBorderWidth = Constants.hexagonImageBorderWidthDefault
            }
        } else {
            avatarBorderColor = UIColor.clear
            avatarBorderWidth = Constants.hexagonImageBorderWidthDefault
        }
        
        self.avatarView.tc_makeHexagon(borderWidth: avatarBorderWidth, borderColor: avatarBorderColor)
    }
}

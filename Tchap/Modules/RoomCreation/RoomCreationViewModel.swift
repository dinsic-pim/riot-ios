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

import UIKit

/// The view model used by RoomCreationViewController
final class RoomCreationViewModel: RoomCreationViewModelType {
    
    // MARK: - Constants
    
    private enum Constants {
        static let roomRetentionPeriodDefault: uint = 365
    }
    
    // MARK: - Properties
    
    let roomNameFormTextViewModel: FormTextViewModel
    var retentionPeriodInDays: uint
    let homeServerDomain: String
    var selectedRoomType: RoomType
    
    // MARK: - Setup
    
    init(homeServerDomain: String) {
        
        // Room name
        let roomNameFormTextViewModel = FormTextViewModel(placeholder: TchapL10n.roomCreationNamePlaceholder)
        
        var roomNameTextInputProperties = TextInputProperties()
        roomNameTextInputProperties.returnKeyType = .done
        
        roomNameFormTextViewModel.textInputProperties = roomNameTextInputProperties
        
        self.roomNameFormTextViewModel = roomNameFormTextViewModel
        
        // Other properties
        self.retentionPeriodInDays = Constants.roomRetentionPeriodDefault
        self.homeServerDomain = homeServerDomain
        self.selectedRoomType = .privateRestricted()
    }
}

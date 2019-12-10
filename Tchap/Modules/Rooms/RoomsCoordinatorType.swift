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

/// `RoomsCoordinatorType` is a protocol describing a Coordinator that handle rooms navigation flow.
protocol RoomsCoordinatorType: Coordinator, Presentable {
    
    /// Update rooms search text and update rooms display list.
    ///
    /// - Parameters:
    ///   - searchText: The search text used to perform rooms filtering. Set nil to cancel the filtering.
    func updateSearchText(_ searchText: String?)
    
    /// Scroll to the corresponding room cell (if any).
    ///
    /// - Parameters:
    ///   - roomID: The room identifier.
    ///   - animated: tell whether the transition is animated
    func scrollToRoom(with roomID: String, animated: Bool)
}

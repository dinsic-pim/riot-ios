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

/// `HomeCoordinatorType` is a protocol describing a Coordinator that handle home navigation flow.
protocol HomeCoordinatorType: Coordinator, Presentable {
    
    /// Open a specific room.
    ///
    /// - Parameters:
    ///   - roomID: The room identifier.
    ///   - enventID: An optional event id in this room on which the user wants to focus.
    func showRoom(with roomID: String, onEventID eventID: String?)
    
    /// Override or not the users discovery performed by the Contact Manager.
    ///
    /// - Parameters:
    ///   - isOverridden: tell whether the default behavior is overridden.
    func overrideContactManagerUsersDiscovery(_ isOverridden: Bool)
}

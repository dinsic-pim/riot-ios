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

/// The room access rules.
enum RoomAccessRule {
    /// External users are not allowed
    case restricted
    /// External users are allowed to join
    case unrestricted
    /// The room is a 1:1 chat
    case direct
    /// unknown
    case other(String)
    
    /// String identifier
    public var identifier: String {
        switch self {
        case .restricted: return "restricted"
        case .unrestricted: return "unrestricted"
        case .direct: return "direct"
        case .other(let value): return value
        }
    }
    
    public init(identifier: String) {
        let roomAccessRules: [RoomAccessRule] = [.restricted, .unrestricted, .direct]
        if let rule = roomAccessRules.first(where: { $0.identifier == identifier }) {
            self = rule
        } else {
            self = .other(identifier)
        }
    }
}

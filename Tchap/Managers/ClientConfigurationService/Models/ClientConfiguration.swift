/*
Copyright 2024 New Vector Ltd.
Copyright 2016 OpenMarket Ltd

SPDX-License-Identifier: AGPL-3.0-only
Please see LICENSE in the repository root for full details.
 */

import Foundation

struct ClientConfiguration {
    let minimumClientVersion: MinimumClientVersion
}

// MARK: - Decodable
// Note: CodingKeys are the same as ClientConfiguration properties name.
extension ClientConfiguration: Decodable {
}

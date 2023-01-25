//
// Copyright 2021 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Combine
import Foundation
import SwiftUI

/// Using an enum for the screen allows you define the different state cases with
/// the relevant associated data for each case.
enum MockPollHistoryScreenState: MockScreenState, CaseIterable {
    // A case for each state you want to represent
    // with specific, minimal associated data that will allow you
    // mock that screen.
    case active
    case past
    case activeNoMoreContent
    case contentLoading
    case empty
    case emptyLoading
    case emptyNoMoreContent
    case loading
    
    /// The associated screen
    var screenType: Any.Type {
        PollHistory.self
    }
    
    /// Generate the view struct for the screen state.
    var screenView: ([Any], AnyView) {
        var pollHistoryMode: PollHistoryMode = .active
        let pollService = MockPollHistoryService()
        
        switch self {
        case .active:
            pollHistoryMode = .active
        case .activeNoMoreContent:
            pollHistoryMode = .active
            pollService.hasNextBatch = false
        case .past:
            pollHistoryMode = .past
        case .contentLoading:
            pollService.nextBatchPublishers.append(loadingPolls)
        case .empty:
            pollHistoryMode = .active
            pollService.nextBatchPublishers = [noPolls]
        case .emptyLoading:
            pollService.nextBatchPublishers = [noPolls, loadingPolls]
        case .emptyNoMoreContent:
            pollService.hasNextBatch = false
            pollService.nextBatchPublishers = [noPolls]
        case .loading:
            pollService.nextBatchPublishers = [loadingPolls]
        }
        
        let viewModel = PollHistoryViewModel(mode: pollHistoryMode, pollService: pollService)
        
        // can simulate service and viewModel actions here if needs be.
        switch self {
        case .contentLoading, .emptyLoading:
            viewModel.process(viewAction: .loadMoreContent)
        default:
            break
        }
        
        return (
            [pollHistoryMode, viewModel],
            AnyView(PollHistory(viewModel: viewModel.context)
                .environmentObject(AvatarViewModel.withMockedServices()))
        )
    }
}

private extension MockPollHistoryScreenState {
    var noPolls: AnyPublisher<TimelinePollDetails, Error> {
        Empty<TimelinePollDetails, Error>(completeImmediately: true).eraseToAnyPublisher()
    }
    
    var loadingPolls: AnyPublisher<TimelinePollDetails, Error> {
        Empty<TimelinePollDetails, Error>(completeImmediately: false).eraseToAnyPublisher()
    }
}

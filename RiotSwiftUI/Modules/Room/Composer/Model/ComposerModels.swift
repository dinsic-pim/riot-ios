// 
// Copyright 2022 New Vector Ltd
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

import Foundation
import SwiftUI
import WysiwygComposer

struct FormatItem {
    let type: FormatType
    let active: Bool
    let disabled: Bool
}

enum FormatType {
    case bold
    case italic
    case strikethrough
    case underline
}

extension FormatType: CaseIterable, Identifiable {
    var id: Self { self }
}


extension FormatItem: Identifiable {
    var id: FormatType { type }
}

extension FormatItem {
    var icon: String {
        switch type {
        case .bold:
            return Asset.Images.bold.name
        case .italic:
            return Asset.Images.italic.name
        case .strikethrough:
            return Asset.Images.strikethrough.name
        case .underline:
            return Asset.Images.underlined.name
        }
    }
    
    var accessibilityIdentifier: String {
        switch type {
        case .bold:
            return "boldButton"
        case .italic:
            return "italicButton"
        case .strikethrough:
            return "strikethroughButton"
        case .underline:
            return "underlineButton"
        }
    }
}

extension FormatType {
    var action: WysiwygAction {
        switch self {
        case .bold:
            return .bold
        case .italic:
            return .italic
        case .strikethrough:
            return .strikeThrough
        case .underline:
            return .underline
        }
    }
    
    var composerAction: ComposerAction {
        switch self {
        case .bold:
            return .bold
        case .italic:
            return .italic
        case .strikethrough:
            return .strikeThrough
        case .underline:
            return .underline
        }
    }
}

enum ComposerViewAction {
    case cancel
}

enum ComposerViewModelResult {
    case cancel
}



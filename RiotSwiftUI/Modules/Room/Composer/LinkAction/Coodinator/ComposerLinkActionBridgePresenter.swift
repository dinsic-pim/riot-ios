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
import WysiwygComposer

protocol ComposerLinkActionBridgePresenterDelegate: AnyObject {
    
}


final class ComposerLinkActionBridgePresenter: NSObject {
    private var coordinator: ComposerLinkActionCoordinator?
    private var linkAction: LinkAction
    
    weak var delegate: ComposerLinkActionBridgePresenterDelegate?
    
    init(linkAction: LinkActionWrapper) {
        self.linkAction = linkAction.linkAction
        super.init()
    }
    
    func present(from viewController: UIViewController, animated: Bool) {
        let composerLinkActionCoordinator = ComposerLinkActionCoordinator(linkAction: linkAction)
        let presentable = composerLinkActionCoordinator.toPresentable()
        viewController.present(presentable, animated: animated, completion: nil)
        composerLinkActionCoordinator.start()
        coordinator = composerLinkActionCoordinator
    }
}

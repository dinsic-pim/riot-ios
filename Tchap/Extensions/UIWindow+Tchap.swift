// 
// Copyright 2024 New Vector Ltd
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

import UIKit

extension UIWindow {
    
    // Screen recording can be prevented on iOS by listening to `UIScreen.capturedDidChangeNotification` and masking the screen content.
    //
    // But screenshot cannot be prevented.
    // We can be informed the user made a screenshot by listening to `UIApplication.userDidTakeScreenshotNotification`,
    // but we are informed after the screenshot took place and cannot mask any screen content because it's too late.
    //
    // But iOS auto mask content of Secured UITextField when capturing or recording screen.
    //
    // The hack is too embed any view (such as root window) in a Secured UITextField and iOS will mask it on screen capture or recording.
    //
    // Any screen capture or recording will end in a blank picture or movie in the Photos gallery.
    
    // from: https://stackoverflow.com/a/77922186/399439
    
    func makeSecure() {
        let field = UITextField()

        let view = UIView(frame: CGRect(x: 0, y: 0, width: field.frame.self.width, height: field.frame.self.height))

        let image = UIImageView(image: UIImage())
        image.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)

        field.isSecureTextEntry = true

        self.addSubview(field)
        view.addSubview(image)

        self.layer.superlayer?.addSublayer(field.layer)
        field.layer.sublayers?.last!.addSublayer(self.layer)

        field.leftView = view
        field.leftViewMode = .always
    }
}

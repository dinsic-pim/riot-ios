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

/// UI component style variant 1
@objcMembers
final class Variant1Style: NSObject, Style {
    
    static let shared = Variant1Style()
    
    let statusBarStyle: UIStatusBarStyle = kVariant1StatusBarStyle
    
    let backgroundColor: UIColor = kVariant1PrimaryBgColor
    let separatorColor: UIColor = kVariant1ActionColor
    
    let primarySubTextColor: UIColor = kVariant1PrimarySubTextColor
    let secondaryTextColor: UIColor = kVariant1SecondaryTextColor
    
    func applyStyle(onNavigationBar navigationBar: UINavigationBar) {
        navigationBar.isTranslucent = false
        navigationBar.barTintColor = kVariant1PrimaryBgColor
        navigationBar.tintColor = kVariant1ActionColor
        navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: kVariant1PrimaryTextColor]
    }
    
    func applyStyle(onButton button: UIButton) {
        button.setTitleColor(kVariant1ActionColor, for: .normal)
    }
    
    func applyStyle(onTextField textField: UITextField) {
        textField.textColor = kVariant1ActionColor
        textField.tintColor = kVariant1ActionColor
    }
}

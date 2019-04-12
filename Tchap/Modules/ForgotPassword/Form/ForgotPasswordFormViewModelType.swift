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

protocol ForgotPasswordFormViewModelDelegate: class {
    func forgotPasswordFormViewModel(_ viewModel: ForgotPasswordFormViewModelType, shouldHideConfirmPasswordTextField isHidden: Bool)
}

/// Protocol describing the view model used by ForgotPasswordFormViewController
protocol ForgotPasswordFormViewModelType {
    
    /// Login view model
    var loginTextViewModel: FormTextViewModelType { get }
    
    /// Password view model
    var passwordTextViewModel: FormTextViewModelType { get }
    
    /// Confirm password view model
    var confirmPasswordTextViewModel: FormTextViewModelType { get }
    
    /// The potential delegate
    var delegate: ForgotPasswordFormViewModelDelegate? { get set }
    
    /// Authentication form validation
    func validateForm() -> AuthenticationFormValidationResult
}

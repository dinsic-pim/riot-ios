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

/// The view model used by RegistrationFormViewController
final class RegistrationFormViewModel: RegistrationFormViewModelType {
    
    // MARK: - Properties
    
    let loginTextViewModel: FormTextViewModelType
    let passwordTextViewModel: FormTextViewModelType
    let confirmPasswordTextViewModel: FormTextViewModelType
    
    // MARK: - Setup
    
    init() {
        
        // Email
        
        let emailTextViewModel = FormTextViewModel(placeholder: TchapL10n.registrationMailPlaceholder,
                                                  additionalInfo: TchapL10n.registrationMailAdditionalInfo)
        
        var mailTextFieldProperties = TextInputProperties()
        mailTextFieldProperties.keyboardType = .emailAddress
        mailTextFieldProperties.returnKeyType = .next
        
        if #available(iOS 10.0, *) {
            mailTextFieldProperties.textContentType = .emailAddress
        }
        
        emailTextViewModel.textInputProperties = mailTextFieldProperties
        
        // Password
        
        var passwordTextFieldProperties = TextInputProperties()
        passwordTextFieldProperties.isSecureTextEntry = true
        if #available(iOS 11.0, *) {
            passwordTextFieldProperties.textContentType = .password
        }
        
        let passwordTextViewModel = FormTextViewModel(placeholder: TchapL10n.registrationPasswordPlaceholder)
        passwordTextViewModel.textInputProperties = passwordTextFieldProperties
        
        // Confirm password
        
        let confirmPasswordTextViewModel = FormTextViewModel(placeholder: TchapL10n.registrationConfirmPasswordPlaceholder)
        confirmPasswordTextViewModel.textInputProperties = passwordTextFieldProperties
        
        let textViewModels = [
            emailTextViewModel,
            passwordTextViewModel,
            confirmPasswordTextViewModel
        ]
        
        var index = 0
        for textViewModel in textViewModels {
            let returnKeyType: UIReturnKeyType
            
            if index >= textViewModels.count - 1 {
                returnKeyType = .done
            } else {
                returnKeyType = .next
            }
            textViewModel.textInputProperties.returnKeyType = returnKeyType
            index+=1
        }
        
        self.loginTextViewModel = emailTextViewModel
        self.passwordTextViewModel = passwordTextViewModel
        self.confirmPasswordTextViewModel = confirmPasswordTextViewModel
    }
    
    // MARK: - Public
    
    func validateForm() -> AuthenticationFormValidationResult {
        
        let errorTitle = TchapL10n.errorTitleDefault
        
        guard let mail = self.loginTextViewModel.value else {
            let errorPresentable = ErrorPresentableImpl(title: errorTitle, message: TchapL10n.authenticationErrorInvalidEmail)
            return .failure(errorPresentable)
        }
        
        guard let password = self.passwordTextViewModel.value else {
            let errorPresentable = ErrorPresentableImpl(title: errorTitle, message: TchapL10n.authenticationErrorMissingPassword)
            return .failure(errorPresentable)
        }
        
        let confirmPassword = self.confirmPasswordTextViewModel.value
        
        let validationResult: AuthenticationFormValidationResult
        
        var errorMessage: String? = nil
        
        if !MXTools.isEmailAddress(mail) {
            print("[RegistrationViewModel] Invalid email")
            errorMessage = TchapL10n.authenticationErrorInvalidEmail
        } else if password.isEmpty {
            print("[RegistrationViewModel] Missing Password")
            errorMessage = TchapL10n.authenticationErrorMissingPassword
        } else if password.count < FormRules.passwordMinLength {
            print("[RegistrationViewModel] Invalid Password")
            errorMessage = TchapL10n.authenticationErrorInvalidPassword(FormRules.passwordMinLength)
        } else if password != confirmPassword {
            print("[RegistrationViewModel] Passwords don't match")
            errorMessage = TchapL10n.registrationErrorPasswordsDontMatch
        }
        
        if let errorMessage = errorMessage {
            let errorPresentable = ErrorPresentableImpl(title: errorTitle, message: errorMessage)
            validationResult = .failure(errorPresentable)
        } else {
            let authenticationFields = AuthenticationFields(login: mail, password: password)
            validationResult = .success(authenticationFields)
        }
        
        return validationResult
    }
}

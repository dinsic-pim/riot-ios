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

/// Used to transform authentication or registration error to `ErrorPresentable`
final class AuthenticationErrorPresentableMaker {
    
    // MARK: - Public
    
    func errorPresentable(from error: Error) -> ErrorPresentable? {
        
        // Error presentable specific to Tchap module
        let tchapErrorPresentable: ErrorPresentable?
        
        switch error {
        case let authenticationServiceError as AuthenticationServiceError:
            tchapErrorPresentable = self.authenticationServiceErrorPresentable(from: authenticationServiceError)
        case let restClientBuilderError as RestClientBuilderError:
            tchapErrorPresentable = self.restClientBuilderErrorPresentable(from: restClientBuilderError)
        case let registrationServiceError as RegistrationServiceError:
            tchapErrorPresentable = self.registrationServiceErrorPresentable(from: registrationServiceError)
        default:
            tchapErrorPresentable = nil
        }
        
        guard tchapErrorPresentable == nil else {
            return tchapErrorPresentable
        }
        
        let nsError = error as NSError
        
        // Ignore connection cancellation error
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            print("[AuthenticationErrorPresentableMaker] Auth request cancelled")
            return nil
        }
        
        if let resourceLimitExceededErrorPresentable = self.resourceLimitExceededErrorPresentable(from: error) {
            return resourceLimitExceededErrorPresentable
        }
        
        let title: String
        let message: String
        
        // Translate the error code to a human message
        if let localizedFailureReason = nsError.localizedFailureReason {
            title = localizedFailureReason
        } else {
            title = Bundle.mxk_localizedString(forKey: "login_error_title")
        }
        
        let dict = nsError.userInfo
        
        if !dict.isEmpty {
            
            if let errCode = dict[kMXErrorCodeKey] as? String {
                switch errCode {
                case kMXErrCodeStringForbidden:
                    message = Bundle.mxk_localizedString(forKey: "login_error_forbidden")
                case kMXErrCodeStringUnknownToken:
                    message = Bundle.mxk_localizedString(forKey: "login_error_unknown_token")
                case kMXErrCodeStringBadJSON:
                    message = Bundle.mxk_localizedString(forKey: "login_error_bad_json")
                case kMXErrCodeStringNotJSON:
                    message = Bundle.mxk_localizedString(forKey: "login_error_bad_json")
                case kMXErrCodeStringLimitExceeded:
                    message = Bundle.mxk_localizedString(forKey: "login_error_limit_exceeded")
                case kMXErrCodeStringUserInUse:
                    message = Bundle.mxk_localizedString(forKey: "login_error_user_in_use")
                case kMXErrCodeStringLoginEmailURLNotYet:
                    message = Bundle.mxk_localizedString(forKey: "login_error_login_email_not_yet")
                case kMXErrCodeStringThreePIDInUse:
                    message = TchapL10n.authenticationErrorEmailInUse
                case kMXErrCodeStringPasswordTooShort:
                    message = TchapL10n.passwordPolicyTooShortPwdError
                case kMXErrCodeStringPasswordNoDigit:
                    message = TchapL10n.passwordPolicyWeakPwdError
                case kMXErrCodeStringPasswordNoLowercase:
                    message = TchapL10n.passwordPolicyWeakPwdError
                case kMXErrCodeStringPasswordNoUppercase:
                    message = TchapL10n.passwordPolicyWeakPwdError
                case kMXErrCodeStringPasswordNoSymbol:
                    message = TchapL10n.passwordPolicyWeakPwdError
                case kMXErrCodeStringWeakPassword:
                    message = TchapL10n.passwordPolicyWeakPwdError
                case kMXErrCodeStringPasswordInDictionary:
                    message = TchapL10n.passwordPolicyPwdInDictError
                default:
                    message = dict[kMXErrorMessageKey] as? String ?? errCode
                }                                
            } else if let localizedError = dict[kMXErrorMessageKey] as? String {
                message = localizedError
            } else {
                message = error.localizedDescription
            }
        } else {
            message = error.localizedDescription
        }
        
        return ErrorPresentableImpl(title: title, message: message)
    }
    
    // MARK: - Private
    
    private func restClientBuilderErrorPresentable(from restClientBuilderError: RestClientBuilderError) -> ErrorPresentable {
        
        let title: String = Bundle.mxk_localizedString(forKey: "login_error_title")
        let message: String
        
        switch restClientBuilderError {
        case .unauthorizedThirdPartyID:
            message = TchapL10n.authenticationErrorUnauthorizedEmail
        default:
            message = TchapL10n.errorMessageDefault
        }
        
        return ErrorPresentableImpl(title: title, message: message)
    }
    
    private func authenticationServiceErrorPresentable(from authenticationServiceError: AuthenticationServiceError) -> ErrorPresentable {
        
        let title: String = Bundle.mxk_localizedString(forKey: "login_error_title")
        let message: String
        
        switch authenticationServiceError {
        case .userAlreadyLoggedIn:
            message = Bundle.mxk_localizedString(forKey: "login_error_already_logged_in")
        default:
            message = TchapL10n.errorMessageDefault
        }
        
        return ErrorPresentableImpl(title: title, message: message)
    }
    
    private func registrationServiceErrorPresentable(from authenticationServiceError: RegistrationServiceError) -> ErrorPresentable {
        
        let title: String = Bundle.mxk_localizedString(forKey: "login_error_title")
        let message: String
        
        switch authenticationServiceError {
        case .userAlreadyLoggedIn:
            message = Bundle.mxk_localizedString(forKey: "login_error_already_logged_in")
        case .invalidPassword(let reason):
            switch reason {
            case .tooShort(let minLength):
                message = TchapL10n.passwordPolicyTooShortPwdDetailedError(minLength)
            case .noDigit:
                message = TchapL10n.passwordPolicyWeakPwdError
            case .noSymbol:
                message = TchapL10n.passwordPolicyWeakPwdError
            case .noUppercase:
                message = TchapL10n.passwordPolicyWeakPwdError
            case .noLowercase:
                message = TchapL10n.passwordPolicyWeakPwdError
            }
        default:
            message = TchapL10n.errorMessageDefault
        }
        
        return ErrorPresentableImpl(title: title, message: message)
    }
    
    private func resourceLimitExceededErrorPresentable(from error: Error) -> ErrorPresentable? {
        let errorInfo = (error as NSError).userInfo
        
        guard !errorInfo.isEmpty, let errorCode = errorInfo["errcode"] as? String, errorCode == kMXErrCodeStringResourceLimitExceeded else {
            return nil
        }

        return resourceLimitExceededErrorPresentable(from: errorInfo)
    }
    
    private func resourceLimitExceededErrorPresentable(from errorDict: [AnyHashable: Any]) -> ErrorPresentable {
        
        let title: String = Bundle.mxk_localizedString(forKey: "login_error_resource_limit_exceeded_title")
        var message = ""
        
        // Parse error data
        let limitType = errorDict[kMXErrorResourceLimitExceededLimitTypeKey] as? String
        
        // Build the message content
        
        if limitType == kMXErrorResourceLimitExceededLimitTypeMonthlyActiveUserValue {
            message += Bundle.mxk_localizedString(forKey: "login_error_resource_limit_exceeded_message_monthly_active_user")
        } else {
            message += Bundle.mxk_localizedString(forKey: "login_error_resource_limit_exceeded_message_default")
        }
        
        message += Bundle.mxk_localizedString(forKey: "login_error_resource_limit_exceeded_message_contact")
        
        return ErrorPresentableImpl(title: title, message: message)
    }
}

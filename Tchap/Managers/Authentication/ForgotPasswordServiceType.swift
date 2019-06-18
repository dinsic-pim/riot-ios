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

/// Protocol describing a service to handle forgot password.
protocol ForgotPasswordServiceType {
    
    /// Validate the forgot password parameters.
    /// - check first whether the provided password (if any) complies with the server's policy (if any).
    /// - then request a verification email and return the corresponding third PID credentials for registration.
    ///
    /// - Parameters:
    ///   - password: (optional) The password to check against the policy.
    ///   - email: The user email.
    ///   - completion: A closure called when the operation succeeds. Provide the three PID credentials.
    func validateParametersAndRequestForgotPasswordEmail(password: String?, email: String, completion: @escaping (MXResponse<ThreePIDCredentials>) -> Void) -> MXHTTPOperation
    
    /// Reset user password.
    ///
    /// - Parameters:
    ///   - threePIDCredentials: The user three PID credentials given by forgot password email.
    ///   - newPassword: The new user password.
    ///   - completion: A closure called when the operation complete.
    func resetPassword(withEmailCredentials threePIDCredentials: ThreePIDCredentials, newPassword: String, completion: @escaping (MXResponse<Void>) -> Void) -> MXHTTPOperation
}

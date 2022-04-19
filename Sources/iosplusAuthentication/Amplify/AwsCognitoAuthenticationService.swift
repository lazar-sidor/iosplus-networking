//
//  AwsCognitoAuthenticationService.swift
//
//  Created by Lazar Sidor on 19.04.2022.
//

import UIKit
import iosplusCoreAuthentication
import Amplify
import AWSCognitoAuthPlugin

public final class AwsCognitoAuthenticationService: NSObject {
    private let configUrl: URL?
    private let pendingResetUsernameKey = "kPendingResetUsernameKey"

    public init(configUrl: URL?) {
        self.configUrl = configUrl
        super.init()
    }

    public var pendingResetUsername: String? {
        get {
            return UserDefaults.standard.object(forKey: pendingResetUsernameKey) as? String
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: pendingResetUsernameKey)
        }
    }

    public func fetchCurrentAuthSession() {
        _ = Amplify.Auth.fetchAuthSession { result in
            switch result {
            case .success(let session):
                print("Is user signed in - \(session.isSignedIn)")
            case .failure(let error):
                print("Fetch session failed with error \(error)")
            }
        }
    }

    private func makeUnsupportedError() -> Error? {
        let error = NSError(domain: String(describing: AwsCognitoAuthenticationService.self), code: 0, userInfo: [NSLocalizedDescriptionKey: "Not supported"])
        return error
    }

    private func fetchToken(completion: @escaping ((_ token: String?) -> Void)) {
        _ = Amplify.Auth.fetchAuthSession { result in
            switch result {
            case .success(let session):
                if (session.isSignedIn) {
                    if let sess = session as? AWSAuthCognitoSession {
                        let result = sess.getCognitoTokens()
                        switch result {
                        case .success(let tokens):
                            let accessToken = tokens.accessToken
                            print ("Acces token: \(accessToken )")
                            let idToken = tokens.idToken
                            print ("Id token: \(idToken )")
                            let refreshToken = tokens.refreshToken
                            print ("Refresh token: \(refreshToken )")
                            completion(idToken)
                        case .failure(let error):
                            print("Fetch user tokens failed with error \(error)")
                            completion(nil)
                        }
                    }
                }
            case .failure(let error):
                print("Fetch session failed with error \(error)")
                completion(nil)
            }
        }
    }
}

// MARK: - AuthenticationAppDelegate
extension AwsCognitoAuthenticationService: AuthenticationAppDelegate {
    public func handleApplication(_ application: UIApplication, languageCode: String, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            if let configUrl = self.configUrl {
                let configuration = try AmplifyConfiguration(configurationFile: configUrl)
                try Amplify.configure(configuration)
            } else {
                try Amplify.configure()
            }
        } catch {
            print("An error occurred setting up Amplify: \(error)")
        }
    }

    @available(iOS 13.0, *)
    public func handleScene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {}

    public func handleApplication(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
        return true
    }

    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {}

    public func application(_ application: UIApplication, didReceiveRemoteNotification notification: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(.noData)
    }
}

// MARK: - AuthenticationProvider
extension AwsCognitoAuthenticationService: AuthenticationProvider {
    public func isResetPasswordPendingForConfirmedUser() -> Bool {
        return pendingResetUsername != nil
    }

    public func signOut() {
        _ = Amplify.Auth.signOut(options: AuthSignOutRequest.Options(globalSignOut: true, pluginOptions: nil))
    }

    public func getIdToken(completion: @escaping (_ token: String?, _ error: Error?) -> Void) {
        fetchToken { (idToken: String?) in
            completion(idToken, nil)
        }
    }

    public func authenticateUser(credentials: AuthorizationCredentials, context: UIViewController, completion: @escaping AuthenticationCompletion) {

        guard credentials.authorizationType == .usernameAndPassword else {
            completion(AuthenticationResult.failure(error: makeUnsupportedError()))
            return
        }

        if let _ = Amplify.Auth.getCurrentUser() {
            self.signOut()
        }

        var username: String? = credentials.username
        if username == nil {
            username = credentials.phoneNumberData?.phoneNumber
        }

        Amplify.Auth.signIn(username: username!, password: credentials.password) { result in
            do {
                let authResult = try result.get()
                switch authResult.nextStep {
                default:
                    print(authResult)
                    break
                }
            }
            catch {
                print("Sign in failed \(String(describing: error))")
                DispatchQueue.main.async {
                    completion(AuthenticationResult.failure(error: error))
                }
            }

            switch result {
            case .success:
                print("Sign in succeeded")
                self.fetchToken { token in
                    DispatchQueue.main.async {
                        completion(AuthenticationResult.success(result: nil, token: token))
                    }
                }
            case .failure(let error):
                print("Sign in failed \(error)")
                let authError: AmplifyError = error
                let errorMessage = authError.errorDescription
                let nsError = NSError(domain: String(describing: AwsCognitoAuthenticationService.self), code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                DispatchQueue.main.async {
                    completion(AuthenticationResult.failure(error: nsError))
                }
            }
        }
    }

    public func registerUser(credentials: AuthorizationCredentials, context: UIViewController, completion: @escaping AuthenticationCompletion) {

        let invalidCredentials = NSError(domain: String(describing: AwsCognitoAuthenticationService.self), code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid Credentials"])

        guard credentials.authorizationType == .usernameAndPassword else {
            DispatchQueue.main.async {
                completion(AuthenticationResult.failure(error: invalidCredentials))
            }
            return
        }

        guard credentials.username != nil || credentials.phoneNumberData?.phoneNumber != nil else {
            DispatchQueue.main.async {
                completion(AuthenticationResult.failure(error: invalidCredentials))
            }
            return
        }

        guard credentials.password != nil else {
            DispatchQueue.main.async {
                completion(AuthenticationResult.failure(error: invalidCredentials))
            }
            return
        }

        var userAttributes: AuthUserAttribute?
        if let email = credentials.username {
            userAttributes = AuthUserAttribute(.email, value: email)
        } else if let phone = credentials.phoneNumberData?.phoneNumber {
            userAttributes = AuthUserAttribute(.phoneNumber, value: phone)
        }

        guard userAttributes != nil else {
            DispatchQueue.main.async {
                completion(AuthenticationResult.failure(error: invalidCredentials))
            }
            return
        }

        let options = AuthSignUpRequest.Options(userAttributes: [userAttributes!])
        let username = userAttributes!.value
        Amplify.Auth.signUp(username: username, password: credentials.password, options: options) { result in
            switch result {
            case .success(let signUpResult):
                if case let .confirmUser(deliveryDetails, _) = signUpResult.nextStep {
                    print("Delivery details \(String(describing: deliveryDetails))")
                } else {
                    print("SignUp Complete")
                }
                DispatchQueue.main.async {
                    completion(AuthenticationResult.success(result: nil, token: nil))
                }
            case .failure(let error):
                print("An error occurred while registering a user \(error)")
                DispatchQueue.main.async {
                    completion(AuthenticationResult.failure(error: error))
                }
            }
        }
    }

    public func verifyPhoneNumber(phoneNumber: String, context: UIViewController, completion: @escaping (PhoneNumberData, Error?) -> Void) {
        DispatchQueue.main.async {
            completion(PhoneNumberData.emptyPhoneNumber(), self.makeUnsupportedError())
        }
    }

    public func resetPassword(username: String, context: UIViewController, completion: @escaping ((_ error: Error?, _ requiresConfirmation: Bool) -> Void)) {
        pendingResetUsername = username
        Amplify.Auth.resetPassword(for: username) { result in
            DispatchQueue.main.async {
                do {
                    let resetResult = try result.get()
                    switch resetResult.nextStep {
                    case .confirmResetPasswordWithCode(let deliveryDetails, let info):
                        print("Confirm reset password with code send to - \(deliveryDetails) \(String(describing: info))")
                        completion(nil, true)
                    case .done:
                        print("Reset completed")
                        completion(nil, false)
                    }
                } catch {
                    print("Reset password failed with error \(error)")
                    completion(error, false)
                }
            }
        }
    }

    public func confirmNewUserAndResetPassword(username: String, oldPassword: String, newPassword: String, context: UIViewController, completion: @escaping ((_ error: Error?) -> Void)) {

        var userAttributes: AuthUserAttribute?
        if username.contains("@") {
            userAttributes = AuthUserAttribute(.email, value: username)
        } else {
            userAttributes = AuthUserAttribute(.phoneNumber, value: username)
        }

        let invalidCredentials = NSError(domain: String(describing: AwsCognitoAuthenticationService.self), code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid Credentials"])
        guard userAttributes != nil else {
            DispatchQueue.main.async {
                completion(invalidCredentials)
            }
            return
        }

        Amplify.Auth.signIn(username: username, password: oldPassword) { result in
            do {
                let resetResult = try result.get()
                switch resetResult.nextStep {
                case .confirmSignInWithNewPassword(let info):
                    print("Confirm Sign in - \(String(describing: info))")
                    Amplify.Auth.confirmSignIn(challengeResponse: newPassword) { operationResult in
                        switch operationResult {
                        case .success(let success):
                            print("success --confirmSignIn: \(success)")
                            DispatchQueue.main.async {
                                completion(nil)
                            }
                        case .failure(let error):
                            print("failure --confirmSignIn: \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                completion(error)
                            }
                        }
                    }
                case .done:
                    print("Reset completed")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                default:
                    break
                }
            } catch {
                print("Reset password failed with error \(error)")
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }

    public func changePassword(oldPassword: String, newPassword: String, clientMetaData: [String : String]?, context: UIViewController, completion: @escaping ((_ error: Error?) -> Void)) {
        Amplify.Auth.update(oldPassword: oldPassword, to: newPassword) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Change password succeeded")
                    completion(nil)
                case .failure(let error):
                    let authError: AmplifyError = error
                    let errorMessage = authError.errorDescription
                    let nsError = NSError(domain: String(describing: AwsCognitoAuthenticationService.self), code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    print("Change password failed with error \(error)")
                    completion(nsError)
                }
            }
        }
    }

    public func confirmResetPassword(username: String, newPassword: String, confirmationCode: String, completion: @escaping ((Error?) -> Void)) {
        Amplify.Auth.confirmResetPassword(for: username, with: newPassword, confirmationCode: confirmationCode) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.pendingResetUsername = nil
                    print("Password reset confirmed")
                    completion(nil)
                case .failure(let error):
                    print("Reset password failed with error \(error)")
                    completion(error)
                }
            }
        }
    }

    public func confirmSignUp(username: String, confirmationCode: String, completion: @escaping ((Error?) -> Void)) {
        Amplify.Auth.confirmSignUp(for: username, confirmationCode: confirmationCode) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Confirm signUp succeeded")
                    completion(nil)
                case .failure(let error):
                    print("An error occurred while confirming sign up \(error)")
                    completion(error)
                }
            }
        }
    }
}

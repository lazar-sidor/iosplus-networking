//
//  FirebaseAuthenticationProvider.swift
//
//  Created by Lazar Sidor on 10.01.2022.
//

import UIKit
import Firebase
import GoogleSignIn
import FBSDKLoginKit
import SafariServices
import iosplusCoreAuthentication

public class FirebaseAuthenticationProvider: NSObject {
    private var credentials: AuthorizationCredentials
    private weak var presentingController: UIViewController?
    
    public override init() {
        self.credentials = AuthorizationCredentials()
        super.init()
    }
}

// MARK: - AuthenticationProvider
extension FirebaseAuthenticationProvider: AuthenticationProvider {
    public func signOut() {
        let firebaseAuth = Auth.auth()
        do {
            try firebaseAuth.signOut()
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }

    public func getIdToken(completion: @escaping (_ token: String?, _ error: Error?) -> Void) {
        switch credentials.authorizationType {
        case .facebook:
            completion(AccessToken.current?.tokenString, nil)
        case .google:
            completion( GIDSignIn.sharedInstance.currentUser?.authentication.idToken, nil)
        case .phoneNumber:
            let authUser = Auth.auth().currentUser
            if let user = authUser {
                user.getIDToken { (idToken: String?, tokenError: Error?) in
                    guard tokenError == nil else {
                        completion(idToken, nil)
                        return
                    }
                    completion(nil, tokenError)
                }
            }
        default:
            completion(nil, nil)
        }
    }

    public func verifyPhoneNumber(phoneNumber: String, context: UIViewController, completion: @escaping (_ phoneData: PhoneNumberData, _ error: Error?) -> Void) {
        presentingController = context
        performPhoneNumberVerification(phoneNumber: phoneNumber, context: context, uiDelegate: nil, completion: completion)
    }

    public func registerUser(credentials: AuthorizationCredentials, context: UIViewController, completion: @escaping AuthenticationCompletion) {
        self.credentials = credentials
        presentingController = context

        switch credentials.authorizationType {
        case .facebook:
            performFacebookSignUp(context: context, completion: completion)
        case .google:
            performGoogleSignUp(context: context, completion: completion)
        case .phoneNumber:
            performPhoneNumberSignIn(context: context, completion: completion)
        default:
            let error = NSError(domain: String(describing: FirebaseAuthenticationProvider.self), code: 0, userInfo: [NSLocalizedDescriptionKey: "Not supported"])
            completion(AuthenticationResult.failure(error: error))
        }
    }

    public func authenticateUser(credentials: AuthorizationCredentials, context: UIViewController, completion: @escaping AuthenticationCompletion) {
        self.credentials = credentials
        presentingController = context

        switch credentials.authorizationType {
        case .facebook:
            performFacebookSignIn(context: context, completion: completion)
        case .google:
            performGoogleSignIn(context: context, completion: completion)
        case .phoneNumber:
            performPhoneNumberSignIn(context: context, completion: completion)
        default:
            let error = NSError(domain: String(describing: FirebaseAuthenticationProvider.self), code: 0, userInfo: [NSLocalizedDescriptionKey: "Not supported"])
            completion(AuthenticationResult.failure(error: error))
        }
    }

    public func resetPassword(username: String, context: UIViewController, completion: @escaping ((Error?, Bool) -> Void)) {
        // TODO: - todo
    }

    public func changePassword(oldPassword: String, newPassword: String, clientMetaData: [String: String]?, context: UIViewController, completion: @escaping ((Error?) -> Void)) {
        // TODO: - todo
    }

    public func confirmResetPassword(username: String, newPassword: String, confirmationCode: String, completion: @escaping ((Error?) -> Void)) {
        // TODO: - todo
    }
}

// MARK: - AuthenticationAppDelegate
extension FirebaseAuthenticationProvider: AuthenticationAppDelegate {
    public func handleApplication(_ application: UIApplication, languageCode: String, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        // Firebase
        FirebaseApp.configure()
        Auth.auth().languageCode = languageCode

        // Facebook
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass device token to auth
        Auth.auth().setAPNSToken(deviceToken, type: .prod)
    }

    public func application(_ application: UIApplication, didReceiveRemoteNotification notification: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(notification) {
            completionHandler(.noData)
            return
        }
    }

    @available(iOS 13.0, *)
    public func handleScene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        switch credentials.authorizationType {
        case .facebook:
            FacebookAuthenticationService.scene(scene, openURLContexts: URLContexts)
        case .google:
            GoogleAuthenticationService.scene(scene, openURLContexts: URLContexts)
        case .phoneNumber:
            PhoneNumberAuthenticationService.scene(scene, openURLContexts: URLContexts)
        default:
            break
        }
    }

    public func handleApplication(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        switch credentials.authorizationType {
        case .facebook:
            return FacebookAuthenticationService.application(app, open: url, options: options)
        case .google:
            return GoogleAuthenticationService.application(app, open: url, options: options)
        case .phoneNumber:
            return PhoneNumberAuthenticationService.application(app, open: url, options: options)
        default:
            return true
        }
    }
}

// MARK: - Private
private extension FirebaseAuthenticationProvider {
    func performFacebookSignUp(context: UIViewController, completion: @escaping AuthenticationCompletion) {
        let error = NSError(domain: String(describing: FirebaseAuthenticationProvider.self), code: 0, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
        completion(AuthenticationResult.failure(error: error))
    }
    
    func performFacebookSignIn(context: UIViewController, completion: @escaping AuthenticationCompletion) {
        if let fbAppId = credentials.facebookSettings?.applicationId,
            let fbAppName = credentials.facebookSettings?.applicationDisplayName,
            let fbPermissions = credentials.facebookSettings?.permisssions {
                FacebookAuthenticationService.performFacebookSignIn(fbAppId: fbAppId, displayName: fbAppName, permissions: fbPermissions, context: context, completion: completion)
        } else {
            let error = NSError(domain: String(describing: FirebaseAuthenticationProvider.self), code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing Facebook app information"])
            completion(AuthenticationResult.failure(error: error))
        }
    }
    
    func performGoogleSignUp(context: UIViewController, completion: @escaping AuthenticationCompletion) {
        let error = NSError(domain: String(describing: FirebaseAuthenticationProvider.self), code: 0, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
        completion(AuthenticationResult.failure(error: error))
    }
    
    func performGoogleSignIn(context: UIViewController, completion: @escaping AuthenticationCompletion) {
        GoogleAuthenticationService.performGoogleSignIn(context: context, completion: completion)
    }

    func performPhoneNumberVerification(phoneNumber: String, context: UIViewController, uiDelegate: AuthUIDelegate?, completion: @escaping (_ phoneData: PhoneNumberData, _ error: Error?) -> Void) {
        PhoneNumberAuthenticationService.verifyPhoneNumber(phoneNumber: phoneNumber, context: context, uiDelegate: uiDelegate) { (_ verificationId: String?, verificationError: Error?) in
            let phoneInfo = PhoneNumberData(phoneNumber: phoneNumber, verificationId: verificationId, verificationCode: nil)
            completion(phoneInfo, verificationError)
        }
    }
    
    func performPhoneNumberSignIn(context: UIViewController, completion: @escaping AuthenticationCompletion) {
        if let verificationId = credentials.phoneNumberData?.verificationId, let verificationCode = credentials.phoneNumberData?.verificationCode {
            PhoneNumberAuthenticationService.performPhoneNumberSignIn(verificationId: verificationId, verificationCode: verificationCode, context: context, completion: completion)
        }
    }
}

// MARK: - AuthUIDelegate
extension FirebaseAuthenticationProvider: AuthUIDelegate {
    public func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        if viewControllerToPresent is SFSafariViewController {
            let safariController = viewControllerToPresent as! SFSafariViewController
            safariController.delegate = self
            presentingController?.present(viewControllerToPresent, animated: flag, completion: completion)
        }
    }

    public func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        presentingController?.dismiss(animated: flag, completion: completion)
    }
}

// MARK: - SFSafariViewControllerDelegate
extension FirebaseAuthenticationProvider: SFSafariViewControllerDelegate {
}

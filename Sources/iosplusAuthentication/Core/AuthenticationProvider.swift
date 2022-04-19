//
//  AuthenticationProvider.swift
//
//  Created by Lazar Sidor on 22.01.2022.
//

import UIKit

/// Enum which holds the supported authentication types
public enum AuthorizationType {
    case usernameAndPassword
    case google
    case facebook
    case phoneNumber
    case unsupported
}

/// Structure which contain different credential types used to register or authenticate a user.
/// Examples:
/// - authentication based on credentials uses username and password
/// - authentication based on phone number uses phoneNumberData
/// - authentication with Facebook uses facebookSettings structure
public struct AuthorizationCredentials {
    public var authorizationType: AuthorizationType = .unsupported
    public var facebookSettings: FacebookSettings?
    public var phoneNumberData: PhoneNumberData?
    public var username: String?
    public var password: String?

    public init() {
    }
}

/// Structure which holds phone number specific information used for authentication
public struct PhoneNumberData {
    public var phoneNumber: String
    public var countryCode: String?
    public var verificationId: String?
    public var verificationCode: String?

    public init(phoneNumber: String, countryCode: String? = nil, verificationId: String? = nil, verificationCode: String? = nil) {
        self.phoneNumber = phoneNumber
        self.countryCode = countryCode
        self.verificationId = verificationId
        self.verificationCode = verificationCode
    }

    public static func emptyPhoneNumber() -> PhoneNumberData {
        return PhoneNumberData(phoneNumber: "", countryCode: nil, verificationId: nil, verificationCode: nil)
    }
}

/// Structure which holds phone Facebook specific information used for authentication
public struct FacebookSettings {
    public var applicationId: String
    public var applicationDisplayName: String?
    public var permisssions: [String] = ["email"]
}

/// Type of result returned by all user registration and authentication methods
public enum AuthenticationResult<Entity, Error, String> {
    case success(result: Entity?, token: String?)
    case failure(error: Error?)
}

public typealias AuthenticationCompletion = ((AuthenticationResult<AnyObject, Error, String>) -> Void)

/// Protocol which has to be implemeneted by each authentication service
/// This is used to pass information from AppDelegate events
public protocol AuthenticationAppDelegate: AnyObject {
    func handleApplication(_ application: UIApplication, languageCode: String, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
    @available(iOS 13.0, *)
    func handleScene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>)
    func handleApplication(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    func application(_ application: UIApplication, didReceiveRemoteNotification notification: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
}

/// Protocol which declares authentication specific functions
public protocol AuthenticationProvider: AuthenticationAppDelegate {
    /// - verifyPhoneNumber: used for sign in with Phone Number
    func verifyPhoneNumber(phoneNumber: String, context: UIViewController, completion: @escaping (_ phoneData: PhoneNumberData, _ error: Error?) -> Void)
    /// - registerUser: used for register a user with variuous supported credentials (email and password, phone number, Facebook Account, Google account, etc)
    func registerUser(credentials: AuthorizationCredentials, context: UIViewController, completion: @escaping AuthenticationCompletion)
    /// - authenticateUser: used for authenticate a user with variuous supported credentials (email and password, phone number, Facebook Account, Google account, etc)
    func authenticateUser(credentials: AuthorizationCredentials, context: UIViewController, completion: @escaping AuthenticationCompletion)
    /// - resetPassword: used to initiate the reset password flow for a given registered user (username)
    func resetPassword(username: String, context: UIViewController, completion: @escaping ((_ error: Error?, _ requiresConfirmation: Bool) -> Void))
    /// - changePassword: - used to change the password for a valid user and a known old password
    func changePassword(oldPassword: String, newPassword: String, clientMetaData: [String: String]?, context: UIViewController, completion: @escaping ((_ error: Error?) -> Void))
    /// - confirmResetPassword: used to complete the reset password flow for a given username, a new password and a confirmation code received by sms or email
    func confirmResetPassword(username: String, newPassword: String, confirmationCode: String, completion: @escaping ((_ error: Error?) -> Void))
    /// - getIdToken: used to refresh the authentication ID token in case this is configured to expire (e.g: Firebase's ID token expire after 1 hour and we need to refresh it before every API call, if expired)
    func getIdToken(completion: @escaping (_ token: String?, _ error: Error?) -> Void)
    /// - signOut: used to clear the authentication session anf to mark the user logged out 
    func signOut()
}

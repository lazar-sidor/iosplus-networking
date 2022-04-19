//
//  FacebookAuthenticationService.swift
//
//  Created by Lazar Sidor on 10.01.2022.
//

import UIKit
import Firebase
import FacebookCore
import FBSDKLoginKit
import iosplusCoreAuthentication

public final class FacebookAuthenticationService: NSObject {
    public class func performFacebookSignIn(fbAppId: String, displayName: String, permissions: [String], context: UIViewController, completion: @escaping AuthenticationCompletion) {
        Settings.shared.appID = fbAppId
        Settings.shared.displayName = displayName
        
        let loginManager = LoginManager()
        loginManager.logIn(permissions: permissions, from: context) { result, error in
            guard error == nil else {
                completion(AuthenticationResult.failure(error: error))
                return
            }
            guard let accessToken = AccessToken.current else {
                let error = NSError(
                    domain: "FBSignInError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Unexpected sign in result: required authentication token is missing."]
                )
                completion(AuthenticationResult.failure(error: error))
                return
            }
            
            let credential = FacebookAuthProvider.credential(withAccessToken: accessToken.tokenString)
            Auth.auth().signIn(with: credential) { result, error in
                guard error == nil else {
                    completion(AuthenticationResult.failure(error: error))
                    return
                }
                completion(AuthenticationResult.success(result: result, token: nil))
            }
        }
    }

    @available(iOS 13.0, *)
    public class func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }

        ApplicationDelegate.shared.application(
            UIApplication.shared,
            open: url,
            sourceApplication: nil,
            annotation: [UIApplication.OpenURLOptionsKey.annotation]
        )
    }

    public class func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
    }
}

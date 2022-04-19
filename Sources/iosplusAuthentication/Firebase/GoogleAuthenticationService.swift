//
//  GoogleAuthenticationService.swift
//
//  Created by Lazar Sidor on 10.01.2022.
//

import UIKit
import Firebase
import FBSDKLoginKit
import GoogleSignIn
import iosplusCoreAuthentication

public final class GoogleAuthenticationService: NSObject {
    public class func performGoogleSignIn(context: UIViewController, completion: @escaping AuthenticationCompletion) {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }

        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)

        // Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(with: config, presenting: context) { user, error in
            guard error == nil else {
                completion(AuthenticationResult.failure(error: error))
                return
            }

            guard
                let authentication = user?.authentication,
                let idToken = authentication.idToken
            else {
                let error = NSError(
                    domain: "GIDSignInError",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Unexpected sign in result: required authentication data is missing."
                    ]
                )
                completion(AuthenticationResult.failure(error: error))
                return
            }

            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: authentication.accessToken)

            Auth.auth().signIn(with: credential) { result, error in
                guard error == nil else {
                    completion(AuthenticationResult.failure(error: error))
                    return
                }
                completion(AuthenticationResult.success(result: result, token: nil))
            }
        }
    }
    
    public class func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    @available(iOS 13.0, *)
    public class func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }
        
        _ = GIDSignIn.sharedInstance.handle(url)
    }
}

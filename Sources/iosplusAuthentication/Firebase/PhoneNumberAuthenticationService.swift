//
//  PhoneNumberAuthenticationService.swift
//
//  Created by Lazar Sidor on 10.01.2022.
//

import UIKit
import Firebase
import FirebaseAuth
import iosplusCoreAuthentication

public final class PhoneNumberAuthenticationService: NSObject {
    public class func verifyPhoneNumber(phoneNumber: String, context: UIViewController, uiDelegate: AuthUIDelegate?, completion: @escaping ((_ verificationId: String?, _ error: Error?) -> Void)) {
        PhoneAuthProvider.provider()
            .verifyPhoneNumber(phoneNumber, uiDelegate: uiDelegate) { verificationID, error in
                completion(verificationID, error)
            }
    }
    
    public class func performPhoneNumberSignIn(verificationId: String, verificationCode: String, context: UIViewController, completion: @escaping AuthenticationCompletion) {
        let credential = PhoneAuthProvider.provider()
            .credential(withVerificationID: verificationId, verificationCode: verificationCode)
        Auth.auth().signIn(with: credential) { result, error in
            guard error == nil else {
                completion(AuthenticationResult.failure(error: error))
                return
            }

            if let user = result?.user {
                user.getIDToken { (idToken: String?, tokenError: Error?) in
                    guard tokenError == nil else {
                        completion(AuthenticationResult.failure(error: tokenError))
                        return
                    }
                    completion(AuthenticationResult.success(result: result, token: idToken))
                }
            }
        }
    }
    
    public class func presentPhoneAuthController(from context: UIViewController, saveHandler: @escaping (String) -> Void) {
        let phoneAuthController = UIAlertController(
            title: "Register with Phone Number",
            message: nil,
            preferredStyle: .alert
        )
        phoneAuthController.addTextField { textfield in
            textfield.placeholder = "Enter verification code."
            if #available(iOS 12.0, *) {
                textfield.textContentType = .oneTimeCode
            } else {
                // Fallback on earlier versions
            }
        }
        
        let onContinue: (UIAlertAction) -> Void = { _ in
            let text = phoneAuthController.textFields!.first!.text!
            saveHandler(text)
        }
        
        phoneAuthController
            .addAction(UIAlertAction(title: "Continue", style: .default, handler: onContinue))
        phoneAuthController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        context.present(phoneAuthController, animated: true, completion: nil)
    }
    
    public class func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        return Auth.auth().canHandle(url)
    }
    
    @available(iOS 13.0, *)
    public class func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for urlContext in URLContexts {
            let url = urlContext.url
            Auth.auth().canHandle(url)
        }
    }
}

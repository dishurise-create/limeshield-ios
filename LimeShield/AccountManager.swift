import Foundation
import SwiftUI
import AuthenticationServices
import Combine

/// Optional sign-in.
///
/// Lime Shield has no server and never uploads bills, so an account is not required
/// to use the app. Signing in with Apple only stores an anonymous identifier on this
/// device so a Pro subscription can be recognised across the user's own devices.
///
/// NOTE for the build: Sign in with Apple needs the capability enabled in Xcode
/// (target > Signing & Capabilities > + Capability > Sign in with Apple), which
/// requires a paid Apple Developer account. Until then the button returns an error,
/// which this class reports politely instead of crashing.
@MainActor
final class AccountManager: ObservableObject {

    @AppStorage("accountUserID") private var storedUserID = ""
    @AppStorage("accountDisplayName") private var storedName = ""

    @Published var errorMessage: String?

    var isSignedIn: Bool { !storedUserID.isEmpty }
    var displayName: String { storedName.isEmpty ? "Signed in" : storedName }

    func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unexpected sign-in response."
                return
            }
            storedUserID = credential.user
            if let full = credential.fullName {
                let parts = [full.givenName, full.familyName].compactMap { $0 }
                if !parts.isEmpty { storedName = parts.joined(separator: " ") }
            }
            errorMessage = nil

        case .failure(let error):
            // Code 1000/1001 is the usual "capability not enabled yet" case.
            let nsError = error as NSError
            if nsError.code == ASAuthorizationError.canceled.rawValue {
                errorMessage = nil
            } else {
                errorMessage = "Sign in isn't available yet. Enable the Sign in with Apple capability in Xcode to turn it on."
            }
        }
    }

    func signOut() {
        storedUserID = ""
        storedName = ""
        errorMessage = nil
    }
}

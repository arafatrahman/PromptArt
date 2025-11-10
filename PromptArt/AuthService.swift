import Foundation
import FirebaseAuth
import Combine

class AuthService: ObservableObject {
    // This will publish the current user's ID
    @Published var currentUserId: String?
    
    // NEW: This will publish any error messages
    @Published var errorMessage: String?
    
    // This handle tracks the authentication state
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    
    init() {
        self.currentUserId = Auth.auth().currentUser?.uid
        
        // Listen for changes in authentication (login, logout)
        self.authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            self?.currentUserId = user?.uid
        }
    }
    
    deinit {
        // Stop listening when this object is destroyed
        if let handle = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // NEW: Function to sign in
    func signIn(email: String, password: String) {
        self.errorMessage = nil // Clear previous errors
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] (result, error) in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            }
        }
    }
    
    // NEW: Function to create a new account
    func createAccount(email: String, password: String) {
        self.errorMessage = nil // Clear previous errors
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] (result, error) in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            }
        }
    }
    
    // Sign out the current user
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.currentUserId = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }
    }
}

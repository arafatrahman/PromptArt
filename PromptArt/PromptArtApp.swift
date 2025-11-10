import SwiftUI
import FirebaseCore
import FirebaseAuth

// MARK: - APP DELEGATE FOR FIREBASE SETUP
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

// MARK: - MAIN APP ENTRY POINT
@main
struct PromptArtApp: App {
    // Register the app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Initialize our global services
    @StateObject private var localStorage = LocalStorageService()
    @StateObject private var authService = AuthService()
    
    // Read the user's preferred color scheme from storage
    @AppStorage("preferredColorScheme") private var colorSchemeString: String = "dark"

    // Convert the stored string to a ColorScheme enum
    var preferredColorScheme: ColorScheme? {
        switch colorSchemeString {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil // System default
        }
    }
    
    var body: some Scene {
        WindowGroup {
            // Check if a user is currently signed in
            if authService.currentUserId != nil {
                // User is logged in: Show the main app
                MainNavigationView()
                    .environmentObject(localStorage)
                    .environmentObject(authService)
                    .preferredColorScheme(preferredColorScheme)
            } else {
                // User is NOT logged in: Show the login screen
                LoginView()
                    .environmentObject(authService)
                    .preferredColorScheme(preferredColorScheme)
            }
        }
    }
}

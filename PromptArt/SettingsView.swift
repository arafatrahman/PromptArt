import SwiftUI

// This enum defines the options for our picker
enum ColorSchemeOption: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    // This helper converts the enum case to the string we save in AppStorage
    var storageKey: String {
        switch self {
        case .system:
            return "system"
        case .light:
            return "light"
        case .dark:
            return "dark"
        }
    }
}

struct SettingsView: View {
    
    // Reads/writes the "preferredColorScheme" value from UserDefaults
    @AppStorage("preferredColorScheme") private var colorSchemeString: String = "dark"
    
    // NEW: Get the auth service from the environment
    @EnvironmentObject var authService: AuthService
    
    // This maps the string key to the enum case for the Picker
    private var currentScheme: ColorSchemeOption {
        return ColorSchemeOption.allCases.first { $0.storageKey == colorSchemeString } ?? .dark
    }
    
    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                // Picker to change the app theme
                Picker("Theme", selection: $colorSchemeString) {
                    ForEach(ColorSchemeOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option.storageKey)
                    }
                }
                .pickerStyle(.segmented) // Use a segmented control
            }
            
            Section(header: Text("About")) {
                HStack {
                    Text("App Version")
                    Spacer()
                    Text("1.2.0") // Updated version
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Developer")
                    Spacer()
                    Text("Arafat Rahman")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Account")) {
                // This button now calls the real sign-out function
                Button("Sign Out", role: .destructive) {
                    // NEW: Call the sign out function from the auth service
                    authService.signOut()
                }
            }
        }
        .navigationTitle("Settings")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
                .environmentObject(AuthService()) // Add a dummy service for preview
        }
    }
}

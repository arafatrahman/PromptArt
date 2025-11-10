import SwiftUI

// NEW: This enum defines the options for our picker
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
    
    // NEW: Reads/writes the "preferredColorScheme" value from UserDefaults
    // This must match the key used in PromptArtApp
    @AppStorage("preferredColorScheme") private var colorSchemeString: String = "dark"
    
    // This maps the string key to the enum case for the Picker
    private var currentScheme: ColorSchemeOption {
        return ColorSchemeOption.allCases.first { $0.storageKey == colorSchemeString } ?? .dark
    }
    
    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                // NEW: Picker to change the app theme
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
                    Text("1.1.0")
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
                // This is a placeholder for when you add Firebase Auth
                Button("Sign Out", role: .destructive) {
                    // Add your authentication sign-out logic here
                    print("Sign out tapped...")
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
        }
    }
}

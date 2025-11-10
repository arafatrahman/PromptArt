import SwiftUI

struct LoginView: View {
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoginMode = true // Toggles between Login and Sign Up
    
    // Get the authService from the environment
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                Image(systemName: "palette.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(Color.purple)
                    .padding(.bottom, 20)
                
                // LOGIN / SIGN UP TOGGLE
                Picker("Mode", selection: $isLoginMode.animation()) {
                    Text("Log In").tag(true)
                    Text("Create Account").tag(false)
                }
                .pickerStyle(.segmented)
                
                // TEXT FIELDS
                VStack {
                    TextField("Email", text: $email)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                }
                
                // ERROR MESSAGE
                if let errorMessage = authService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                // ACTION BUTTON
                Button(action: handleButtonTapped) {
                    Text(isLoginMode ? "Log In" : "Create Account")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle(isLoginMode ? "Welcome Back" : "Create Account")
            .onAppear {
                authService.errorMessage = nil // Clear errors when view appears
            }
        }
    }
    
    // Handles either login or sign up
    func handleButtonTapped() {
        if isLoginMode {
            authService.signIn(email: email, password: password)
        } else {
            authService.createAccount(email: email, password: password)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthService()) // Add a dummy service for preview
            .preferredColorScheme(.dark)
    }
}

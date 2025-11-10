import SwiftUI
import UIKit
import PhotosUI

struct ImageGenerationView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var prompt: String = ""
    @State private var isGenerating: Bool = false
    @State private var generatedImage: UIImage?
    @State private var generationError: Error?
    @State private var showErrorAlert: Bool = false
    
    @State private var inputImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    
    private let imageSaver = ImageSaverService()
    @State private var showSaveConfirmation = false
    
    // --- Check if we are ready to generate ---
    var canGenerate: Bool {
        return !prompt.isEmpty && inputImage != nil && !isGenerating
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Form {
                    Section(header: Text("Your Prompt")) {
                        TextEditor(text: $prompt)
                            .frame(minHeight: 100)
                            .disabled(isGenerating)
                    }
                    
                    // --- This section is now required ---
                    Section(header: Text("Input Image (Required)")) {
                        
                        if let inputImage {
                            Image(uiImage: inputImage)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                            
                            Button("Clear Image", role: .destructive) {
                                withAnimation {
                                    self.inputImage = nil
                                    self.photoItem = nil
                                }
                            }
                        }
                        
                        PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                            Label(inputImage == nil ? "Select Image" : "Change Image", systemImage: "photo")
                        }
                    }
                    
                    Section {
                        Button(action: {
                            Task {
                                await generateImage()
                            }
                        }) {
                            HStack(alignment: .center, spacing: 8) {
                                Spacer()
                                if isGenerating {
                                    ProgressView()
                                    Text("Generating...")
                                } else {
                                    Label("Generate Image", systemImage: "sparkles")
                                }
                                Spacer()
                            }
                        }
                        // --- Button is disabled if not ready ---
                        .disabled(!canGenerate)
                    }
                    
                    if let image = generatedImage {
                        Section(header: Text("Your Image")) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                            
                            Button(action: saveImage) {
                                Label("Save to Gallery", systemImage: "arrow.down.to.line")
                            }
                        }
                    }
                }
                
                // ... (Rest of the view is unchanged) ...
                if showSaveConfirmation {
                    Text("Image Saved!")
                        .padding()
                        .background(.ultraThickMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showSaveConfirmation = false
                                }
                            }
                        }
                        .padding(.top, 10)
                }
            }
            .navigationTitle("Create Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Image Generation Failed", isPresented: $showErrorAlert, presenting: generationError) { error in
                Button("OK") {}
            } message: { error in
                Text(error.localizedDescription)
            }
            .onChange(of: photoItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        if let image = UIImage(data: data) {
                            DispatchQueue.main.async {
                                withAnimation {
                                    self.inputImage = image
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func generateImage() async {
        // Guard against being called accidentally
        guard let inputImage = self.inputImage else { return }
        
        await MainActor.run {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            isGenerating = true
            generatedImage = nil
            generationError = nil
        }

        print("Starting IMAGE-TO-IMAGE generation...")
        // --- This is now the ONLY path ---
        let result = await ImageGenerationService.shared.generateImage(prompt: prompt, image: inputImage)
        
        await MainActor.run {
            isGenerating = false
            switch result {
            case .success(let image):
                self.generatedImage = image
            case .failure(let error):
                print("Error generating image: \(error.localizedDescription)")
                self.generationError = error
                self.showErrorAlert = true
            }
        }
    }
    
    // Unchanged
    func saveImage() {
        guard let image = generatedImage else { return }
        
        imageSaver.saveUIImage(image) { success, error in
            DispatchQueue.main.async {
                if success {
                    withAnimation {
                        self.showSaveConfirmation = true
                    }
                } else {
                    print("Error saving image: \(error?.localizedDescription ?? "unknown error")")
                    self.generationError = error
                    self.showErrorAlert = true
                }
            }
        }
    }
}

struct ImageGenerationView_Previews: PreviewProvider {
    static var previews: some View {
        ImageGenerationView()
    }
}

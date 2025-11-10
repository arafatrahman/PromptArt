import SwiftUI
import UIKit
import PhotosUI

struct ImageGenerationView: View {
    @Environment(\.dismiss) var dismiss
    
    // MARK: - State Properties
    
    @State private var prompt: String
    @State private var isGenerating: Bool = false
    @State private var generatedImage: UIImage?
    @State private var generationError: Error?
    @State private var showErrorAlert: Bool = false
    
    @State private var inputImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    
    private let imageSaver = ImageSaverService()
    @State private var showSaveConfirmation = false
    
    var canGenerate: Bool {
        return !prompt.isEmpty && inputImage != nil && !isGenerating
    }
    
    // --- Custom Initializer ---
    init(prefilledPrompt: String? = nil) {
        self._prompt = State(initialValue: prefilledPrompt ?? "")
    }

    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Main content is now in a VStack
                VStack(spacing: 0) {
                    
                    // --- 1. Top Section: Result View ---
                    resultView
                    
                    // --- 2. Bottom Section: Input Form ---
                    inputForm
                }
                
                // --- 3. Toast Overlay ---
                if showSaveConfirmation {
                    toastView
                }
            }
            .navigationTitle("Create Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // --- Generate Button in toolbar ---
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        Task {
                            await generateImage()
                        }
                    }) {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Text("Generate")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canGenerate)
                }
            }
            .alert("Image Generation Failed", isPresented: $showErrorAlert, presenting: generationError) { error in
                Button("OK") {}
            } message: { error in
                Text(error.localizedDescription)
            }
            .onChange(of: photoItem, perform: loadPhoto)
        }
    }
    
    // MARK: - Subviews
    
    /// The top view that displays the generated image, input image, or a placeholder.
    private var resultView: some View {
        VStack {
            // --- UPDATED: Wrapped in a ZStack for the save button ---
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    if let generatedImage, let inputImage {
                        // Show the slider
                        ImageComparisonSlider(before: inputImage, after: generatedImage)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                    } else if let inputImage {
                        // Show just the input image
                        Image(uiImage: inputImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        // Placeholder (this remains a fixed size)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .overlay(
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                            )
                            .frame(height: 300) // Fixed height for placeholder ONLY
                    }
                    
                    // Show spinner when loading
                    if isGenerating {
                        ProgressView()
                            .controlSize(.large)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                
                // --- NEW: Save Icon Button ---
                if generatedImage != nil {
                    Button(action: saveImage) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(.ultraThickMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(8) // Padding from the corner
                }
            }
            .padding()
            
        }
        .background(Color(UIColor.systemBackground)) // Match form background
    }
    
    /// The bottom form for user inputs.
    private var inputForm: some View {
        Form {
            Section(header: Text("Your Prompt")) {
                TextEditor(text: $prompt)
                    .frame(minHeight: 100)
                    .disabled(isGenerating)
            }
            
            Section(header: Text("Input Image (Required)")) {
                
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    Label(inputImage == nil ? "Select Image" : "Change Image", systemImage: "photo")
                }
                
                if inputImage != nil {
                    Button("Clear Image", role: .destructive) {
                        withAnimation {
                            self.inputImage = nil
                            self.photoItem = nil
                        }
                    }
                }
            }
            
            // --- REMOVED: The "Save" Section ---
        }
    }
    
    /// The toast view for save confirmation.
    private var toastView: some View {
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
    
    // MARK: - Functions
    
    /// Loads the selected photo from the PhotosPickerItem.
    private func loadPhoto(_ newItem: PhotosPickerItem?) {
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
    
    /// Calls the AI service to generate a new image.
    private func generateImage() async {
        guard let inputImage = self.inputImage else { return }
        
        await MainActor.run {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            isGenerating = true
            generatedImage = nil // Clear previous result
            generationError = nil
        }

        print("Starting IMAGE-TO-IMAGE generation...")
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
    
    /// Saves the generated image to the photo gallery.
    private func saveImage() {
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

// MARK: - Previews
struct ImageGenerationView_Previews: PreviewProvider {
    static var previews: some View {
        ImageGenerationView(prefilledPrompt: "A cat wearing a tiny hat")
    }
}

// MARK: - IMAGE COMPARISON SLIDER

struct ImageComparisonSlider: View {
    let before: UIImage
    let after: UIImage
    
    @State private var sliderPosition: CGFloat = 0.5
    @State private var isDragging: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            let drag = DragGesture()
                .onChanged { value in
                    self.isDragging = true
                    // Clamp the slider position between 0 and 1
                    self.sliderPosition = max(0, min(1, value.location.x / geometry.size.width))
                }
                .onEnded { _ in
                    self.isDragging = false
                }
            
            ZStack(alignment: .leading) {
                // 1. Before Image (Bottom)
                Image(uiImage: before)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height) // Use geometry
                    .clipped()

                // 2. After Image (Top, clipped)
                Image(uiImage: after)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height) // Use geometry
                    .clipped()
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle()
                                .frame(width: geometry.size.width * sliderPosition)
                            Spacer(minLength: 0)
                        }
                        .frame(width: geometry.size.width)
                    )
                
                // 3. Slider Handle
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                        .frame(width: max(0, geometry.size.width * sliderPosition - 2))
                    
                    // Divider Line
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 4)
                    
                    Spacer(minLength: 0)
                }
                .frame(width: geometry.size.width)
                .overlay(
                    // Handle Circle
                    Image(systemName: "arrow.left.and.right.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.white)
                        .shadow(radius: 3)
                        .padding(2)
                        .position(x: geometry.size.width * sliderPosition, y: geometry.size.height / 2)
                        .scaleEffect(isDragging ? 1.15 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
                )
            }
            .contentShape(Rectangle())
            .gesture(drag)
        }
        // Set the aspect ratio of the slider to match the "before" image
        .aspectRatio(before.size, contentMode: .fit)
    }
}

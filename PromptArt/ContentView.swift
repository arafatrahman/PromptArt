import SwiftUI
import Combine

// Firebase & Image Loading
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import SDWebImageSwiftUI

// MARK: - APP ENTRY POINT & FIREBASE SETUP

// This class handles the initial Firebase setup
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Optional: Configure Firestore settings
        let settings = Firestore.firestore().settings
        settings.isPersistenceEnabled = true // Enable offline caching
        Firestore.firestore().settings = settings
        
        return true
    }
}

@main
struct PromptArtApp: App {
    // Register the app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // We will use this to manage our saved prompts across the app
    @StateObject private var localStorage = LocalStorageService()
    
    var body: some Scene {
        WindowGroup {
            // Start with the SplashView
            SplashView()
                // Make the local storage available to all child views
                .environmentObject(localStorage)
                // Set preferred color schemes (optional)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - MODELS

struct CategoryModel: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let name: String
    let imageUrl: String
}

struct PromptModel: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let title: String
    let promptText: String
    let imageUrl: String
    let isFeatured: Bool? // NEW: Added for featured prompts
}

// MARK: - SERVICES

class FirestoreService: ObservableObject {
    private let db = Firestore.firestore()
    
    // Fetch all categories
    func getCategories(completion: @escaping ([CategoryModel]) -> Void) {
        db.collection("categories").order(by: "name").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching categories: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion([])
                return
            }
            
            let categories = documents.compactMap { doc -> CategoryModel? in
                try? doc.data(as: CategoryModel.self)
            }
            completion(categories)
        }
    }
    
    // Fetch all prompts for a specific category
    func getPromptsForCategory(categoryId: String, completion: @escaping ([PromptModel]) -> Void) {
        db.collection("categories").document(categoryId).collection("prompts").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching prompts: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion([])
                return
            }
            
            let prompts = documents.compactMap { doc -> PromptModel? in
                try? doc.data(as: PromptModel.self)
            }
            completion(prompts)
        }
    }
    
    // NEW: Fetch all prompts marked as "isFeatured"
    func getFeaturedPrompts(completion: @escaping ([PromptModel]) -> Void) {
        // This query scans all "prompts" collections across all "categories"
        db.collectionGroup("prompts").whereField("isFeatured", isEqualTo: true).getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching featured prompts: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion([])
                return
            }
            
            let prompts = documents.compactMap { doc -> PromptModel? in
                try? doc.data(as: PromptModel.self)
            }
            completion(prompts)
        }
    }
}

class LocalStorageService: ObservableObject {
    private let savedPromptsKey = "savedPrompts"
    @Published var savedPrompts: [PromptModel] = []
    
    init() {
        loadSavedPrompts()
    }
    
    private func loadSavedPrompts() {
        guard let data = UserDefaults.standard.data(forKey: savedPromptsKey) else {
            self.savedPrompts = []
            return
        }
        
        if let prompts = try? JSONDecoder().decode([PromptModel].self, from: data) {
            self.savedPrompts = prompts
        }
    }
    
    private func persistPrompts() {
        if let data = try? JSONEncoder().encode(savedPrompts) {
            UserDefaults.standard.set(data, forKey: savedPromptsKey)
        }
        // Notify subscribers that the data has changed
        objectWillChange.send()
    }
    
    func savePrompt(_ prompt: PromptModel) {
        if !isPromptSaved(prompt) {
            savedPrompts.append(prompt)
            persistPrompts()
        }
    }
    
    func removePrompt(_ prompt: PromptModel) {
        savedPrompts.removeAll { $0.id == prompt.id }
        persistPrompts()
    }
    
    func isPromptSaved(_ prompt: PromptModel) -> Bool {
        savedPrompts.contains { $0.id == prompt.id }
    }
    
    func refresh() {
        loadSavedPrompts()
    }
}

class ImageSaverService: NSObject {
    private var completionHandler: ((Bool, Error?) -> Void)?
    
    func saveImageFromUrl(_ imageUrl: String, completion: @escaping (Bool, Error?) -> Void) {
        self.completionHandler = completion
        
        guard let url = URL(string: imageUrl) else {
            completion(false, nil) // Invalid URL
            return
        }
        
        // Use SDWebImageManager to download the image
        SDWebImageManager.shared.loadImage(with: url, options: [], progress: nil) { [weak self] (image, data, error, cacheType, finished, imageURL) in
            if let error = error {
                self?.completionHandler?(false, error)
                return
            }
            
            if let image = image {
                // Save the downloaded image to the photo album
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(self?.image(_:didFinishSavingWithError:contextInfo:)), nil)
            } else {
                self?.completionHandler?(false, nil) // Failed to get image
            }
        }
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            completionHandler?(false, error)
        } else {
            completionHandler?(true, nil)
        }
    }
}

// MARK: - SPLASH SCREEN

struct SplashView: View {
    @State private var isActive = false
    
    var body: some View {
        if isActive {
            MainNavigationView()
        } else {
            ZStack {
                // Use a dark background
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                VStack {
                    Spacer()
                    Image(systemName: "palette.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundColor(Color.purple)
                    
                    Text("PromptArt")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .padding(.top, 10)
                    
                    Text("Find, Copy & Create Stunning AI Art Prompts")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    
                    Spacer()
                    ProgressView() // Loading indicator
                    Spacer()
                }
                .padding()
            }
            .onAppear {
                // Wait for 2.5 seconds then navigate
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

// MARK: - MAIN NAVIGATION VIEW (TABBAR)

struct MainNavigationView: View {
    @EnvironmentObject var localStorage: LocalStorageService
    
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            
            // NEW: Create Tab
            NavigationStack {
                CreatePromptView()
            }
            .tabItem {
                Label("Create", systemImage: "plus.square.fill")
            }
            
            NavigationStack {
                SavedPromptsView()
            }
            .tabItem {
                Label("Saved", systemImage: "bookmark.fill")
            }
            // **FIXED** Removed the .onAppear that was causing bugs
        }
    }
}

// MARK: - SCREEN: HOME

struct HomeView: View {
    @StateObject private var firestoreService = FirestoreService()
    @State private var categories: [CategoryModel] = []
    @State private var featuredPrompts: [PromptModel] = [] // NEW: For featured
    @State private var isLoading = true
    @State private var searchText = "" // NEW: For search
    
    // Define a 2-column grid layout
    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    // NEW: Computed property for search
    var filteredCategories: [CategoryModel] {
        if searchText.isEmpty {
            return categories
        } else {
            return categories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .padding(.top, 200)
            } else {
                
                // NEW: Featured Prompts Section
                if !featuredPrompts.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Featured")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(featuredPrompts) { prompt in
                                    NavigationLink(value: prompt) {
                                        FeaturedPromptCard(prompt: prompt)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
                
                // Categories Section
                VStack(alignment: .leading) {
                    Text("Categories")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    if filteredCategories.isEmpty {
                        Text("No categories matching '\(searchText)' found.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 16) {
                            ForEach(filteredCategories) { category in
                                NavigationLink(value: category) {
                                    CategoryCard(category: category)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("PromptArt")
        .navigationDestination(for: CategoryModel.self) { category in
            CategoryDetailView(category: category)
        }
        .navigationDestination(for: PromptModel.self) { prompt in
            PromptDetailView(prompt: prompt) // Add this for featured links
        }
        .searchable(text: $searchText, prompt: "Search Categories") // NEW: Search bar
        .onAppear {
            if categories.isEmpty { // Only load once
                loadData()
            }
        }
    }
    
    func loadData() {
        isLoading = true
        
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        firestoreService.getCategories { fetchedCategories in
            self.categories = fetchedCategories
            dispatchGroup.leave()
        }
        
        // NEW: Load featured prompts
        dispatchGroup.enter()
        firestoreService.getFeaturedPrompts { fetchedPrompts in
            self.featuredPrompts = fetchedPrompts
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isLoading = false
        }
    }
}

// MARK: - SCREEN: CATEGORY DETAIL

struct CategoryDetailView: View {
    let category: CategoryModel
    
    @StateObject private var firestoreService = FirestoreService()
    @State private var prompts: [PromptModel] = []
    @State private var isLoading = true
    @State private var searchText = "" // NEW: For search
    
    // Define a 2-column grid layout
    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    // NEW: Computed property for search
    var filteredPrompts: [PromptModel] {
        if searchText.isEmpty {
            return prompts
        } else {
            return prompts.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 200)
            } else if prompts.isEmpty {
                Text("No prompts found in this category.")
                    .foregroundColor(.secondary)
                    .padding(.top, 200)
            } else if filteredPrompts.isEmpty {
                Text("No prompts matching '\(searchText)' found.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(filteredPrompts) { prompt in // Use filtered list
                        NavigationLink(value: prompt) {
                            PromptGridItem(prompt: prompt)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(category.name)
        .navigationDestination(for: PromptModel.self) { prompt in
            PromptDetailView(prompt: prompt)
        }
        .searchable(text: $searchText, prompt: "Search Prompts") // NEW: Search bar
        .onAppear {
            if prompts.isEmpty { // Only load once
                loadData()
            }
        }
    }
    
    func loadData() {
        guard let categoryId = category.id else {
            isLoading = false
            return
        }
        
        isLoading = true
        firestoreService.getPromptsForCategory(categoryId: categoryId) { fetchedPrompts in
            self.prompts = fetchedPrompts
            self.isLoading = false
        }
    }
}

// MARK: - SCREEN: PROMPT DETAIL

struct PromptDetailView: View {
    let prompt: PromptModel
    @EnvironmentObject var localStorage: LocalStorageService
    
    @State private var isSaved: Bool = false
    @State private var isSavingImage = false
    @State private var showSaveConfirmation = false
    @State private var saveConfirmationMessage = ""
    @State private var showingFullScreenImage = false // NEW: For full-screen
    
    private let imageSaver = ImageSaverService()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Image
                WebImage(url: URL(string: prompt.imageUrl))
                    .resizable()
                    .indicator(.activity)
                    .transition(.fade)
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 400)
                    .clipped()
                    .onTapGesture {
                        showingFullScreenImage = true // NEW: Show full-screen
                    }
                
                // Prompt Text Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Prompt")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(prompt.promptText)
                        .font(.body)
                        .lineSpacing(5)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                }
                .padding()
                
                // Buttons
                VStack(spacing: 12) {
                    // Copy Prompt
                    Button(action: copyPrompt) {
                        Label("Copy Prompt", systemImage: "doc.on.doc")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    // Save Image
                    Button(action: saveImage) {
                        if isSavingImage {
                            ProgressView()
                                .tint(.primary)
                        } else {
                            Label("Save Image to Gallery", systemImage: "arrow.down.to.line")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isSavingImage)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle(prompt.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Share Button
                Button(action: sharePrompt) {
                    Image(systemName: "square.and.arrow.up")
                }
                
                // Save Button
                Button(action: toggleSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                }
            }
        }
        .onAppear {
            isSaved = localStorage.isPromptSaved(prompt)
        }
        // This is the simple "Toast" or "Snackbar" replacement
        .overlay(
            Group {
                if showSaveConfirmation {
                    Text(saveConfirmationMessage)
                        .padding()
                        .background(.ultraThickMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .onAppear {
                            // Hide after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showSaveConfirmation = false
                                }
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 10)
        )
        // NEW: Full-screen image sheet
        .sheet(isPresented: $showingFullScreenImage) {
            FullScreenImageView(imageUrl: prompt.imageUrl)
        }
    }
    
    func showConfirmation(_ message: String) {
        saveConfirmationMessage = message
        withAnimation {
            showSaveConfirmation = true
        }
    }
    
    func copyPrompt() {
        UIPasteboard.general.string = prompt.promptText
        showConfirmation("Prompt Copied!")
    }
    
    func saveImage() {
        isSavingImage = true
        imageSaver.saveImageFromUrl(prompt.imageUrl) { success, error in
            if success {
                showConfirmation("Image saved to gallery!")
            } else {
                showConfirmation("Error: Could not save image.")
                print(error?.localizedDescription ?? "Unknown error")
            }
            isSavingImage = false
        }
    }
    
    func sharePrompt() {
        let textToShare = "Check out this AI art prompt!\n\n\(prompt.title)\n\n\(prompt.promptText)"
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else { return }
        
        let activityVC = UIActivityViewController(activityItems: [textToShare], applicationActivities: nil)
        rootViewController.present(activityVC, animated: true, completion: nil)
    }
    
    func toggleSave() {
        if isSaved {
            localStorage.removePrompt(prompt)
            showConfirmation("Prompt removed.")
        } else {
            localStorage.savePrompt(prompt)
            showConfirmation("Prompt saved!")
        }
        isSaved.toggle()
    }
}

// MARK: - SCREEN: SAVED PROMPTS

struct SavedPromptsView: View {
    @EnvironmentObject var localStorage: LocalStorageService
    
    var body: some View {
        Group {
            if localStorage.savedPrompts.isEmpty {
                VStack {
                    Image(systemName: "bookmark.slash")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80)
                        .foregroundColor(.secondary)
                    Text("No Saved Prompts")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top)
                    Text("Tap the bookmark icon on a prompt to save it here, or create your own.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List {
                    ForEach(localStorage.savedPrompts) { prompt in
                        NavigationLink(value: prompt) {
                            SavedPromptRow(prompt: prompt)
                        }
                    }
                    .onDelete(perform: removePrompts)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Saved Prompts")
        .navigationDestination(for: PromptModel.self) { prompt in
            PromptDetailView(prompt: prompt)
        }
    }
    
    func removePrompts(at offsets: IndexSet) {
        for index in offsets {
            let prompt = localStorage.savedPrompts[index]
            localStorage.removePrompt(prompt)
        }
    }
}

// MARK: - NEW SCREEN: CREATE PROMPT

struct CreatePromptView: View {
    @EnvironmentObject var localStorage: LocalStorageService
    @Environment(\.displayScale) var displayScale // For image
    
    @State private var title = ""
    @State private var promptText = ""
    @State private var showSaveConfirmation = false
    
    // A default placeholder image for user-created prompts
    private let defaultImageUrl = "https://firebasestorage.googleapis.com/v0/b/promptartapp.appspot.com/o/placeholders%2Fuser_prompt.png?alt=media&token=c1a3b4d5-e6f7-8901-2345-6789abcdef12"

    var body: some View {
        Form {
            Section(header: Text("Prompt Details")) {
                TextField("Title", text: $title)
                
                VStack(alignment: .leading) {
                    Text("Prompt Text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $promptText)
                        .frame(minHeight: 200)
                        .padding(4)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                }
            }
            
            Section {
                Button(action: saveCustomPrompt) {
                    Label("Save Custom Prompt", systemImage: "bookmark.fill")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(title.isEmpty || promptText.isEmpty)
            }
        }
        .navigationTitle("Create Prompt")
        // Simple "Toast" confirmation
        .overlay(
            Group {
                if showSaveConfirmation {
                    Text("Prompt Saved!")
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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 10)
        )
    }
    
    func saveCustomPrompt() {
        // Create a new prompt model
        let newPrompt = PromptModel(
            id: UUID().uuidString, // Generate a unique local ID
            title: title,
            promptText: promptText,
            imageUrl: defaultImageUrl,
            isFeatured: false
        )
        
        // Save using the local storage service
        localStorage.savePrompt(newPrompt)
        
        // Show confirmation and clear fields
        withAnimation {
            showSaveConfirmation = true
        }
        title = ""
        promptText = ""
        
        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


// MARK: - NEW VIEW: FULL SCREEN IMAGE

struct FullScreenImageView: View {
    @Environment(\.dismiss) var dismiss
    let imageUrl: String
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            WebImage(url: URL(string: imageUrl))
                .resizable()
                .indicator(.activity)
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale *= delta
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            if scale < 1.0 {
                                withAnimation { scale = 1.0 }
                            }
                        }
                )
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}


// MARK: - REUSABLE WIDGET: CATEGORY CARD

struct CategoryCard: View {
    let category: CategoryModel
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image
            WebImage(url: URL(string: category.imageUrl))
                .resizable()
                .indicator(.activity)
                .transition(.fade)
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 180, maxHeight: 220)
            
            // Gradient Overlay
            LinearGradient(
                colors: [.black.opacity(0.8), .clear],
                startPoint: .bottom,
                endPoint: .center
            )
            
            // Text
            Text(category.name)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding()
                .shadow(radius: 3)
        }
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
    }
}

// MARK: - NEW WIDGET: FEATURED PROMPT CARD

struct FeaturedPromptCard: View {
    let prompt: PromptModel
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            WebImage(url: URL(string: prompt.imageUrl))
                .resizable()
                .indicator(.activity)
                .transition(.fade)
                .aspectRatio(contentMode: .fill)
                .frame(width: 240, height: 160)
            
            LinearGradient(
                colors: [.black.opacity(0.7), .clear],
                startPoint: .bottom,
                endPoint: .center
            )
            
            Text(prompt.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(12)
                .lineLimit(2)
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }
}

// MARK: - REUSABLE WIDGET: PROMPT GRID ITEM

struct PromptGridItem: View {
    let prompt: PromptModel
    
    var body: some View {
        VStack(alignment: .leading) {
            WebImage(url: URL(string: prompt.imageUrl))
                .resizable()
                .indicator(.activity)
                .transition(.fade)
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 180) // Give a consistent starting height
                .clipped()
            
            Text(prompt.title)
                .font(.headline)
                .lineLimit(2)
                .padding(10)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - REUSABLE WIDGET: SAVED PROMPT ROW

struct SavedPromptRow: View {
    let prompt: PromptModel
    
    var body: some View {
        HStack(spacing: 12) {
            WebImage(url: URL(string: prompt.imageUrl))
                .resizable()
                .indicator(.activity)
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(prompt.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(prompt.promptText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
    }
}

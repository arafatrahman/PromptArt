import Foundation

enum APIService {
    static var apiKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String else {
            fatalError("GEMINI_API_KEY not found in Info.plist")
        }
        return key
    }
}

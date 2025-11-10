import Foundation
import UIKit
// We are NO LONGER using the GoogleGenerativeAI library, so the import is removed.

// MARK: - REQUEST STRUCTS
// These are the simple structs for our manual URLSession request
struct RequestInlineData: Codable {
    let mimeType: String
    let data: String
}

struct RequestPart: Codable {
    var text: String? = nil
    var inlineData: RequestInlineData? = nil
    
    init(text: String) {
        self.text = text
        self.inlineData = nil
    }
    
    init(inlineData: RequestInlineData) {
        self.text = nil
        self.inlineData = inlineData
    }
}

struct GeminiImageRequest: Codable {
    let contents: [RequestContent]
}
struct RequestContent: Codable {
    let parts: [RequestPart]
}

// MARK: - RESPONSE STRUCTS
// These are for decoding the manual response
struct GeminiImageResponse: Codable {
    let candidates: [Candidate]?
    let error: GeminiError?
}
struct Candidate: Codable {
    let content: ResponseContent?
    let finishReason: String?
}
struct ResponseContent: Codable {
    let parts: [ResponsePart]?
}
struct ResponsePart: Codable {
    let inlineData: InlineData?
    let text: String?
}
struct InlineData: Codable {
    let mimeType: String
    let data: String
}
struct GeminiError: Codable, LocalizedError {
    let code: Int?
    let message: String?
    let status: String?
    var errorDescription: String? {
        return message ?? "An unknown API error occurred."
    }
}

// MARK: - ERROR ENUM (CORRECTED)
enum ImageGenError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Int, String) // Holds HTTP status code and message
    case noData
    case decodingError(Error)
    case noImageFound
    case base64DecodingFailed
    case apiError(String)
    case promptBlocked(String)
    case modelError(String) // <-- THIS IS THE NEWLY ADDED CASE
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The API endpoint URL was invalid."
        case .requestFailed(let code, let msg): return "The network request failed (Code: \(code)). \(msg)"
        case .noData: return "No data was received from the server."
        case .decodingError(let error): return "Failed to decode the server response. See console for details. Error: \(error.localizedDescription)"
        case .noImageFound: return "No image data was found in the API response. Check the console for the raw server response."
        case .base64DecodingFailed: return "Failed to decode the base64 image data."
        case .apiError(let message): return "The API returned an error: \(message)"
        case .promptBlocked(let reason): return "The prompt was blocked by safety filters. Reason: \(reason)"
        case .modelError(let message): return "An unexpected error occurred: \(message)" // <-- AND ITS DESCRIPTION
        }
    }
}

// MARK: - IMAGE GENERATION SERVICE (Reverted to URLSession)
class ImageGenerationService {
    
    static let shared = ImageGenerationService()
    
    // The model from your curl command
    private let endpointURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent"
    
    // --- THIS IS NOW AN ASYNC FUNCTION USING URLSession ---
    func generateImage(prompt: String, image: UIImage) async -> Result<UIImage, Error> {
        
        // 1. Prepare Image Data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return .failure(ImageGenError.base64DecodingFailed)
        }
        let base64String = imageData.base64EncodedString()
        
        // 2. Prepare URL and Request
        guard let url = URL(string: "\(endpointURL)?key=\(APIService.apiKey)") else {
            return .failure(ImageGenError.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 3. Build Request Body
        let textPart = RequestPart(text: prompt)
        let imagePart = RequestPart(inlineData: RequestInlineData(mimeType: "image/jpeg", data: base64String))
        let requestBody = GeminiImageRequest(
            contents: [
                RequestContent(parts: [textPart, imagePart])
            ]
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            return .failure(ImageGenError.decodingError(error))
        }
        
        // 4. Perform Async Network Call
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // This debug print is still essential
            if let responseString = String(data: data, encoding: .utf8) {
                print("--- GEMINI API RESPONSE ---")
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status Code: \(httpResponse.statusCode)")
                }
                print(responseString)
                print("---------------------------")
            }
            
            // Check for non-200 HTTP status
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                return .failure(ImageGenError.requestFailed(code, errorMsg))
            }

            // 5. Decode Response
            let apiResponse = try JSONDecoder().decode(GeminiImageResponse.self, from: data)
                
            if let apiError = apiResponse.error {
                return .failure(ImageGenError.apiError(apiError.localizedDescription))
            }

            if let firstCandidate = apiResponse.candidates?.first,
               let reason = firstCandidate.finishReason,
               reason.lowercased().contains("safety") {
                return .failure(ImageGenError.promptBlocked(reason))
            }
            
            // 6. Extract Image
            guard let base64String = apiResponse.candidates?.first?.content?.parts?.first(where: { $0.inlineData != nil })?.inlineData?.data else {
                return .failure(ImageGenError.noImageFound)
            }
            
            guard let imageData = Data(base64Encoded: base64String) else {
                return .failure(ImageGenError.base64DecodingFailed)
            }
            
            if let image = UIImage(data: imageData) {
                return .success(image)
            } else {
                return .failure(ImageGenError.base64DecodingFailed)
            }
            
        } catch {
            // This catch block will now work correctly
            return .failure(ImageGenError.modelError(error.localizedDescription))
        }
    }
}

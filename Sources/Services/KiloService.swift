import Foundation
import UIKit

enum KiloError: Error, LocalizedError {
    case notConfigured
    case networkError(Error)
    case badResponse(Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:         return "Kilo API key not configured"
        case .networkError(let e):   return "Network error: \(e.localizedDescription)"
        case .badResponse(let code): return "API error \(code)"
        case .decodingError(let msg): return "Could not parse response: \(msg)"
        }
    }
}

actor KiloService {
    static let baseURL = "https://api.kilo.ai/api/gateway"

    private let apiKey: String
    private let model: String
    private let session: URLSession

    init(apiKey: String, model: String = "anthropic/claude-sonnet-4-6") {
        self.apiKey = apiKey
        self.model  = model
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 30
        cfg.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - Carb estimation (text)

    func estimateCarbs(description: String) async throws -> CarbEstimate {
        let prompt = """
        Estimate the carbohydrates for this meal: "\(description)"
        Respond with valid JSON only, no markdown, no explanation outside the JSON.
        Format: {"food_name": string, "carbs_g": number, "confidence": "high"|"medium"|"low", "notes": string}
        Use "high" confidence when the food is specific and well-known, "medium" for typical portions, "low" for vague descriptions.
        """
        return try await callAPI(userContent: [["type": "text", "text": prompt]])
    }

    // MARK: - Carb estimation (photo)

    func estimateCarbs(image: UIImage, hint: String = "") async throws -> CarbEstimate {
        guard let jpeg = image.jpegData(compressionQuality: 0.7) else {
            throw KiloError.decodingError("Could not compress image")
        }
        let b64 = jpeg.base64EncodedString()
        let hintText = hint.isEmpty ? "" : " The user says: \"\(hint)\"."
        let prompt = """
        Look at this meal photo and estimate the carbohydrates.\(hintText)
        Respond with valid JSON only, no markdown.
        Format: {"food_name": string, "carbs_g": number, "confidence": "high"|"medium"|"low", "notes": string}
        """
        let content: [[String: Any]] = [
            ["type": "text", "text": prompt],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]]
        ]
        return try await callAPI(userContent: content)
    }

    // MARK: - Core

    private func callAPI(userContent: [[String: Any]]) async throws -> CarbEstimate {
        guard !apiKey.isEmpty else { throw KiloError.notConfigured }

        var req = URLRequest(url: URL(string: "\(Self.baseURL)/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "messages": [
                ["role": "system",
                 "content": "You are a diabetes nutrition expert. Estimate carbohydrates accurately. Always respond with valid JSON only."],
                ["role": "user", "content": userContent]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw KiloError.badResponse(http.statusCode)
        }

        // Extract content from OpenAI-compatible response
        guard
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first   = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw KiloError.decodingError("Unexpected response shape")
        }

        // Parse the JSON content Claude returned
        guard
            let contentData = content.data(using: .utf8),
            let estimate    = try? JSONDecoder().decode(CarbEstimate.self, from: contentData)
        else {
            throw KiloError.decodingError("Could not decode CarbEstimate from: \(content)")
        }

        return estimate
    }
}

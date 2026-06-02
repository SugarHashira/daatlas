import Foundation
import CryptoKit

enum NightscoutError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Nightscout URL"
        case .invalidResponse:
            return "Invalid response from Nightscout"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

actor NightscoutService {
    private let baseURL: URL
    private let apiSecret: String
    private let session: URLSession
    
    static var shared: NightscoutService {
        get async throws {
            let config = UserSettings.shared
            guard let url = await config.nightscoutURL, !url.isEmpty else {
                throw NightscoutError.invalidURL
            }
            guard let secret = await config.nightscoutAPISecret, !secret.isEmpty else {
                throw NightscoutError.invalidURL
            }
            return try NightscoutService(url: url, secret: secret)
        }
    }
    
    init(url: String, secret: String) throws {
        guard let baseURL = URL(string: url) else {
            throw NightscoutError.invalidURL
        }
        
        self.baseURL = baseURL
        self.apiSecret = secret
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    private func hashedSecret() -> String {
        let data = Data(apiSecret.utf8)
        let hash = Insecure.SHA1.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func makeRequest(path: String, queryItems: [URLQueryItem] = []) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        
        guard let url = components?.url else {
            throw NightscoutError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(hashedSecret(), forHTTPHeaderField: "api-secret")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NightscoutError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NightscoutError.httpError(httpResponse.statusCode)
            }
            
            return data
        } catch let error as NightscoutError {
            throw error
        } catch {
            throw NightscoutError.networkError(error)
        }
    }
    
    func fetchTreatments(since: Date? = nil, limit: Int = 1000) async throws -> [NightscoutTreatment] {
        var queryItems = [URLQueryItem(name: "count", value: String(limit))]
        
        if let since = since {
            let formatter = ISO8601DateFormatter()
            let dateString = formatter.string(from: since)
            queryItems.append(URLQueryItem(name: "find[created_at][$gte]", value: dateString))
        }
        
        let data = try await makeRequest(path: "api/v1/treatments.json", queryItems: queryItems)
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([NightscoutTreatment].self, from: data)
        } catch {
            throw NightscoutError.decodingError(error)
        }
    }
    
    func fetchGlucoseEntries(since: Date? = nil, limit: Int = 1000) async throws -> [GlucoseEntry] {
        var queryItems = [
            URLQueryItem(name: "count", value: String(limit)),
            URLQueryItem(name: "type", value: "sgv")
        ]
        
        if let since = since {
            let formatter = ISO8601DateFormatter()
            let dateString = formatter.string(from: since)
            queryItems.append(URLQueryItem(name: "find[dateString][$gte]", value: dateString))
        }
        
        let data = try await makeRequest(path: "api/v1/entries/sgv.json", queryItems: queryItems)
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([GlucoseEntry].self, from: data)
        } catch {
            throw NightscoutError.decodingError(error)
        }
    }
    
    func fetchProfile() async throws -> NightscoutProfile? {
        let data = try await makeRequest(path: "api/v1/profile.json")
        
        do {
            let decoder = JSONDecoder()
            let profiles = try decoder.decode([NightscoutProfile].self, from: data)
            return profiles.first
        } catch {
            throw NightscoutError.decodingError(error)
        }
    }
    
    func testConnection() async throws -> Bool {
        let data = try await makeRequest(path: "api/v1/status.json")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json != nil
    }
}

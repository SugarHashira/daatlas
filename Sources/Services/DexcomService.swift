import Foundation

private struct DexcomAPIError: Decodable {
    let code: String?
    let message: String?
    enum CodingKeys: String, CodingKey {
        case code = "Code"
        case message = "Message"
    }
}

enum DexcomError: Error, LocalizedError {
    case notConfigured
    case invalidCredentials
    case sessionExpired
    case noReadings
    case networkError(Error)
    case serverError(Int, String)   // HTTP status, body snippet

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Dexcom credentials not configured"
        case .invalidCredentials: return "Invalid username or password (check Dexcom Share credentials)"
        case .sessionExpired: return "Session expired — tap Test again"
        case .noReadings: return "No recent readings (check Dexcom Share is active)"
        case .networkError(let e): return "Network: \(e.localizedDescription)"
        case .serverError(let code, let body): return "HTTP \(code): \(body)"
        }
    }
}

actor DexcomService {
    static let shared = DexcomService()

    private let applicationID = "d89443d2-327c-4a6f-89e5-496bbb0317db"
    private var sessionToken: String?
    private var tokenExpiry: Date?

    private init() {}

    func fetchLatestReading() async throws -> DexcomReading {
        let readings = try await fetchLatestReadings(count: 1)
        guard let reading = readings.first else { throw DexcomError.noReadings }
        return reading
    }

    func fetchLatestReadings(count: Int = 1) async throws -> [DexcomReading] {
        let settings = UserSettings.shared
        let username = await settings.dexcomUsername
        let password = await settings.dexcomPassword
        let region = await settings.dexcomRegion

        guard !username.isEmpty, !password.isEmpty else {
            throw DexcomError.notConfigured
        }

        let token = try await getSessionToken(username: username, password: password, region: region)
        do {
            let readings = try await fetchReadings(sessionToken: token, region: region, count: count)
            guard !readings.isEmpty else { throw DexcomError.noReadings }
            return readings
        } catch DexcomError.sessionExpired {
            // Session rejected — force fresh login and retry once
            invalidateSession()
            let freshToken = try await getSessionToken(username: username, password: password, region: region)
            let readings = try await fetchReadings(sessionToken: freshToken, region: region, count: count)
            guard !readings.isEmpty else { throw DexcomError.noReadings }
            return readings
        }
    }

    private func getSessionToken(username: String, password: String, region: DexcomRegion) async throws -> String {
        if let token = sessionToken, let expiry = tokenExpiry, expiry > Date() {
            return token
        }
        let token = try await login(username: username, password: password, region: region)
        sessionToken = token
        tokenExpiry = Date().addingTimeInterval(3600 * 20) // 20h
        return token
    }

    private func login(username: String, password: String, region: DexcomRegion) async throws -> String {
        // Step 1: authenticate account name → get account ID
        let accountID = try await authenticateAccount(username: username, password: password, region: region)
        // Step 2: login with account ID → get session token
        return try await loginWithAccountID(accountID: accountID, password: password, region: region)
    }

    private func authenticateAccount(username: String, password: String, region: DexcomRegion) async throws -> String {
        let url = URL(string: "\(region.baseURL)/ShareWebServices/Services/General/AuthenticatePublisherAccount")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let body: [String: String] = [
            "accountName": username,
            "password": password,
            "applicationId": applicationID
        ]
        req.httpBody = try JSONEncoder().encode(body)
        return try await postForUUID(req: req, errorContext: "authenticate")
    }

    private func loginWithAccountID(accountID: String, password: String, region: DexcomRegion) async throws -> String {
        let url = URL(string: "\(region.baseURL)/ShareWebServices/Services/General/LoginPublisherAccountById")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let body: [String: String] = [
            "accountId": accountID,
            "password": password,
            "applicationId": applicationID
        ]
        req.httpBody = try JSONEncoder().encode(body)
        return try await postForUUID(req: req, errorContext: "login")
    }

    private func postForUUID(req: URLRequest, errorContext: String) async throws -> String {
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            guard let http = response as? HTTPURLResponse else {
                throw DexcomError.networkError(URLError(.badServerResponse))
            }
            guard http.statusCode == 200 else {
                throw DexcomError.serverError(http.statusCode, "[\(errorContext)] \(String(bodyStr.prefix(300)))")
            }
            let uuid = bodyStr.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
            guard uuid.count == 36,
                  UUID(uuidString: uuid) != nil,
                  uuid != "00000000-0000-0000-0000-000000000000" else {
                throw DexcomError.invalidCredentials
            }
            return uuid
        } catch let error as DexcomError {
            throw error
        } catch {
            throw DexcomError.networkError(error)
        }
    }

    private func fetchReadings(sessionToken: String, region: DexcomRegion, count: Int) async throws -> [DexcomReading] {
        var components = URLComponents(string: "\(region.baseURL)/ShareWebServices/Services/Publisher/ReadPublisherLatestGlucoseValues")!
        components.queryItems = [
            URLQueryItem(name: "sessionId", value: sessionToken),
            URLQueryItem(name: "minutes", value: "1440"),
            URLQueryItem(name: "maxCount", value: "\(count)")
        ]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = Data("{}".utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)

            // Dexcom returns an error object when session is invalid
            if let errorObj = try? JSONDecoder().decode(DexcomAPIError.self, from: data),
               errorObj.code != nil {
                invalidateSession()
                throw DexcomError.sessionExpired
            }

            return try JSONDecoder().decode([DexcomReading].self, from: data)
        } catch let error as DexcomError {
            throw error
        } catch {
            throw DexcomError.networkError(error)
        }
    }

    func invalidateSession() {
        sessionToken = nil
        tokenExpiry = nil
    }

    func testConnection() async throws -> DexcomReading {
        invalidateSession()
        return try await fetchLatestReading()
    }
}

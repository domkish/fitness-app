//
//  AuthService.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/24/26.
//

import Foundation

protocol AuthServicing {
    func login(email: String, password: String) async throws -> User
    func register(email: String, password: String) async throws -> User
    func resetPassword(email: String) async throws
    func changePassword(current: String, new: String, confirm: String) async throws
    func updateProfile(name: String) async throws -> User
}

final class AuthService: AuthServicing {
    
    private let baseURL = URL(string: "https://api.vsvault.io/api/")!
    private let userRepository: UserRepository

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    func login(email: String, password: String) async throws -> User {
        let endpoint = URL(string: "auth/login", relativeTo: baseURL)!
        let request = try makeRequest(
            url: endpoint,
            body: ["email": email, "password": password]
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder.api.decode(AuthResponse.self, from: data)

        guard let user = result.user else {
            throw AuthError.server(message: "User missing in response")
        }

        TokenStore.token = result.token
        try userRepository.createOrUpdate(user) // ✅ use repository

        return user
    }

    func register(email: String, password: String) async throws -> User {
        let endpoint = URL(string: "auth/register", relativeTo: baseURL)!
        let request = try makeRequest(
            url: endpoint,
            body: ["email": email, "password": password]
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let result = try JSONDecoder.api.decode(AuthResponse.self, from: data)

        guard let user = result.user else {
            throw AuthError.server(message: "Registration succeeded but user missing")
        }

        TokenStore.token = result.token
        try userRepository.createOrUpdate(user) // ✅ use repository

        return user
    }

    func updateProfile(name: String) async throws -> User {
        guard let token = TokenStore.token else {
            throw AuthError.server(message: "Not authenticated")
        }

        let endpoint = URL(string: "auth/update-profile", relativeTo: baseURL)!
        let body: [String: Any] = ["name": name]

        var request = try makeRequest(url: endpoint, body: body)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let result = try JSONDecoder.api.decode(AuthResponse.self, from: data)

        guard let user = result.user else {
            throw AuthError.server(message: "User missing in response")
        }

        try userRepository.createOrUpdate(user) // ✅ repository call
        return user
    }

    func resetPassword(email: String) async throws {
        let endpoint = URL(string: "auth/forgot-password", relativeTo: baseURL)!
        let request = try makeRequest(url: endpoint, body: ["email": email])

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: nil)
    }

    func changePassword(current: String, new: String, confirm: String) async throws {
        guard let token = TokenStore.token else {
            throw AuthError.server(message: "Not authenticated")
        }

        let endpoint = URL(string: "auth/change-password", relativeTo: baseURL)!
        let body: [String: Any] = [
            "current_password": current,
            "new_password": new,
            "new_password_confirmation": confirm
        ]

        var request = try makeRequest(url: endpoint, body: body)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }
    
    // MARK: - Helpers
    
    private func makeRequest(url: URL, body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return request
    }
    
    private func validate(response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(http.statusCode) else {
            // If there's no body at all
            guard let data = data, !data.isEmpty else {
                throw AuthError.server(message: "Request failed (\(http.statusCode))")
            }

            // Try decoding known error format
            if let error = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                let message =
                    error.errors?
                        .flatMap { $0.value }
                        .joined(separator: "\n")
                    ?? error.message

                throw AuthError.server(message: message)
            }

            // Fallback: show raw server response
            let raw = String(data: data, encoding: .utf8)
                ?? "Unknown server error"

            throw AuthError.server(message: raw)
        }
    }

}

// MARK: - Responses

struct AuthResponse: Decodable {
    let token: String
    let user: User?
}

struct User: Decodable {
    let id: Int
    let name: String
    let email: String
    let isPremium: Bool
    let isImperial: Bool
    let weight: Bool
    let fat: Bool
    let photo: Bool
    let log: Int?
    let theme: String
    let emailVerifiedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: Int,
        name: String,
        email: String,
        isPremium: Bool,
        isImperial: Bool = true,
        weight: Bool = true,
        fat: Bool = true,
        photo: Bool = true,
        log: Int? = nil,
        theme: String = "classic",
        emailVerifiedAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.isPremium = isPremium
        self.isImperial = isImperial
        self.weight = weight
        self.fat = fat
        self.photo = photo
        self.log = log
        self.theme = theme
        self.emailVerifiedAt = emailVerifiedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case isPremium = "is_premium"
        case isImperial
        case weight
        case fat
        case photo
        case log
        case theme
        case emailVerifiedAt = "email_verified_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        isPremium = try container.decode(Bool.self, forKey: .isPremium)
        // Optional imperial flag defaults to true if missing
        isImperial = (try container.decodeIfPresent(Bool.self, forKey: .isImperial)) ?? true
        weight = (try container.decodeIfPresent(Bool.self, forKey: .weight)) ?? true
        fat = (try container.decodeIfPresent(Bool.self, forKey: .fat)) ?? true
        photo = (try container.decodeIfPresent(Bool.self, forKey: .photo)) ?? true
        log = try container.decodeIfPresent(Int.self, forKey: .log)
        // Theme defaults to "classic" if missing
        theme = (try container.decodeIfPresent(String.self, forKey: .theme)) ?? "classic"
        emailVerifiedAt = try container.decodeIfPresent(Date.self, forKey: .emailVerifiedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

struct ErrorResponse: Decodable {
    let message: String
    let errors: [String: [String]]?

    enum CodingKeys: String, CodingKey {
        case message
        case errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        message = try container.decodeIfPresent(String.self, forKey: .message)
            ?? "Unknown error"

        errors = try container.decodeIfPresent(
            [String: [String]].self,
            forKey: .errors
        )
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case server(message: String)
    
    var errorDescription: String? {
        switch self {
        case .server(let message):
            return message
        }
    }
}

extension JSONDecoder {
    static let api: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}


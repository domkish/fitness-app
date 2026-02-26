import Foundation

public protocol SubscriptionServicing {
    func recordPurchase(
        signedTransactionInfo: String,
        signedRenewalInfo: String?
    ) async throws
}

public final class SubscriptionService: SubscriptionServicing {
    private let baseURL = URL(string: "https://api.vsvault.io/api/")!

    public init() {}

    private func makeRequest(url: URL, body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = TokenStore.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return request
    }

    public func recordPurchase(
        signedTransactionInfo: String,
        signedRenewalInfo: String?
    ) async throws {
        let url = baseURL.appendingPathComponent("subscriptions/verify")

        let body: [String: Any] = [
            "platform": "ios",
            "signed_transaction_info": signedTransactionInfo,
            "signed_renewal_info": signedRenewalInfo as Any? ?? NSNull()
        ]

        let request = try makeRequest(url: url, body: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        try validate(response: response, data: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "SubscriptionServiceError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? "Unable to decode response body"
            throw NSError(
                domain: "SubscriptionServiceError",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Request failed with status code \(httpResponse.statusCode): \(bodyString)"]
            )
        }
    }
}


import Foundation
import StoreKit
import Combine

final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    // Configure this to match your App Store Connect or Local StoreKit product ID
    let premiumProductID = "com.simplyfitness.premium.lifetime"

    // Provides a JWS string for a verified purchase result when available.
    // NOTE: StoreKit 2 does not expose Apple-signed JWS directly on-device.
    // The app must supply this closure to return a real JWS from its own server or other mechanism.
    // If not set or returns nil, server verification should support an alternate flow (e.g., sending transactionId)
    // to fetch the Apple JWS for a given transaction.
    var jwsProvider: ((VerificationResult<Transaction>) -> String?)?

    struct PurchaseOutcome {
        let transaction: Transaction
    }

    @MainActor
    @Published private(set) var premiumProduct: Product?
    @MainActor
    @Published private(set) var isPurchasing: Bool = false
    @MainActor
    @Published private(set) var purchaseError: String?
    @MainActor
    @Published private(set) var didCompleteLifetimePurchase: Bool = false

    private var updatesTask: Task<Void, Never>? = nil

    @MainActor
    init() {
        // Start observing transaction updates
        updatesTask = Task { [weak self] in
            await self?.observeTransactions()
        }
        Task { await loadProducts() }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Product Loading
    func loadProducts() async {
        for attempt in 1...3 {
            do {
                let ids = [premiumProductID]
                let bundleID = Bundle.main.bundleIdentifier ?? "nil"
                let receiptPath = Bundle.main.appStoreReceiptURL?.path ?? "nil"
                
                // Storefront diagnostics (StoreKit 1 fallback)
                var storefrontAvailable = false
                if let storefront = SKPaymentQueue.default().storefront {
                    storefrontAvailable = true
                } else {
                }
                
                if attempt == 1 && !storefrontAvailable {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                }

                let products = try await Product.products(for: ids)
                await MainActor.run {
                    self.premiumProduct = products.first
                    if let p = self.premiumProduct {
                    }
                }
                return
            } catch {
                let nsError = error as NSError
                if attempt == 3 {
                    await MainActor.run { self.purchaseError = "Failed to load products: \(error.localizedDescription)" }
                } else {
                    // brief backoff before retry
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
    }

    // MARK: - Purchase
    func purchasePremium() async throws -> PurchaseOutcome? {
        let cachedProduct: Product? = await MainActor.run { self.premiumProduct }

        var product: Product? = cachedProduct
        if product == nil {
            let products = try await Product.products(for: [premiumProductID])
            product = products.first
        }

        guard let product else {
            throw PurchaseError.productUnavailable
        }

        await MainActor.run { isPurchasing = true }
        defer { Task { await MainActor.run { isPurchasing = false } } }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await MainActor.run { self.didCompleteLifetimePurchase = true }

            print("[Purchase] Transaction:",
                  "id:", transaction.id,
                  "productID:", transaction.productID,
                  "originalID:", transaction.originalID,
                  "purchaseDate:", transaction.purchaseDate)

            await transaction.finish()
            return PurchaseOutcome(transaction: transaction)

        case .userCancelled, .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - Helpers
    @MainActor
    func resetPurchaseCompletion() {
        self.didCompleteLifetimePurchase = false
    }

    // MARK: - Server Verification
    func verify(transactionId: UInt64) async throws -> ServerVerificationResponse {
        guard let token = TokenStore.token, !token.isEmpty else {
            throw ServerVerificationError.invalidResponse
        }

        guard let url = URL(string: "https://api.vsvault.io/api/subscriptions/verify") else {
            throw ServerVerificationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "platform": "ios",
            "transaction_id": String(transactionId)
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServerVerificationError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if let bodyString = String(data: data, encoding: .utf8) {
                print("[Verify] Server error \(http.statusCode): \(bodyString)")
            }
            throw ServerVerificationError.serverError(statusCode: http.statusCode)
        }

        return try JSONDecoder().decode(ServerVerificationResponse.self, from: data)
    }

    // MARK: - Purchase + Verify Convenience
    func purchaseAndVerifyPremium() async throws -> Bool {
        if let outcome = try await purchasePremium() {
            let result = try await verify(transactionId: outcome.transaction.id)
            return result.isPremium
        }
        return false
    }

    // MARK: - Restore
    func restorePurchases() async {
        do { try await AppStore.sync() }
        catch { await MainActor.run { self.purchaseError = "Restore failed: \(error.localizedDescription)" } }
    }

    // MARK: - Entitlement Check
    func hasPremiumEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements(for: premiumProductID) {
            if case .verified(_) = result { return true }
        }
        return false
    }

    // MARK: - Transaction Observation
    private func observeTransactions() async {
        for await update in Transaction.updates {
            do {
                let transaction = try checkVerified(update)
                await transaction.finish()
            } catch {
                // Ignore unverified transactions
            }
        }
    }

    // MARK: - Verification helper
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let signedType):
            return signedType
        }
    }

    enum PurchaseError: Error { case productUnavailable }

    // MARK: - Server Verification Types
    struct ServerVerificationResponse: Decodable {
        let isPremium: Bool
        let status: String
        let expiresAt: String?

        enum CodingKeys: String, CodingKey {
            case isPremium = "is_premium"
            case status
            case expiresAt = "expires_at"
        }
    }
    enum ServerVerificationError: Error {
        case invalidURL
        case encodingFailed
        case invalidResponse
        case serverError(statusCode: Int)
    }
}


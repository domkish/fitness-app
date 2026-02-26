import Foundation
import StoreKit
import Combine

final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    // Configure this to match your App Store Connect or Local StoreKit product ID
    let premiumProductID = "com.simplyfitness.premium.lifetime"

    // Provides a JWS string for a verified purchase result when available
    var jwsProvider: ((VerificationResult<Transaction>) -> String?)?

    struct PurchaseOutcome {
        let transaction: Transaction
        let signedTransactionInfo: String
        let signedRenewalInfo: String? // nil for lifetime
    }

    @MainActor
    @Published private(set) var premiumProduct: Product?
    @MainActor
    @Published private(set) var isPurchasing: Bool = false
    @MainActor
    @Published private(set) var purchaseError: String?

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
                let products = try await Product.products(for: ["com.simplyfitness.premium.lifetime"])
                await MainActor.run { self.premiumProduct = products.first }
                return
            } catch {
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
        // 1) Read the cached product on the main actor
        let cachedProduct: Product? = await MainActor.run { self.premiumProduct }
        
        // 2) If no cached product, fetch on a background context
        var product: Product? = cachedProduct
        if product == nil {
            let products = try await Product.products(for: [premiumProductID])
            print("[Purchase] Fallback fetch returned:", products.map(\.id))
            product = products.first
        }
        
        // 3) Guard that we actually have a product
        guard let product else {
            throw PurchaseError.productUnavailable
        }
        
        await MainActor.run { isPurchasing = true }
        defer { Task { await MainActor.run { isPurchasing = false } } }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // Log key transaction fields
                print("[Purchase] Transaction:",
                      "id:", transaction.id,
                      "productID:", transaction.productID,
                      "originalID:", transaction.originalID,
                      "purchaseDate:", transaction.purchaseDate)
                
                // Obtain the JWS using the provided provider closure
                let signedTransactionInfo: String = {
                    if let jws = self.jwsProvider?(verification), !jws.isEmpty {
                        return jws
                    } else {
                        print("[PurchaseManager] ERROR: No JWS available at purchase time. Set PurchaseManager.jwsProvider to supply the JWS.")
                        return ""
                    }
                }()

                await transaction.finish()
                return PurchaseOutcome(
                    transaction: transaction,
                    signedTransactionInfo: signedTransactionInfo,
                    signedRenewalInfo: nil
                )
            case .userCancelled, .pending:
                return nil
            @unknown default:
                return nil
            }
        } catch {
            await MainActor.run { self.purchaseError = error.localizedDescription }
            throw error
        }
    }

    // MARK: - Server Verification
    func verify(signedTransactionInfo: String, signedRenewalInfo: String?) async throws -> ServerVerificationResponse {
        guard !signedTransactionInfo.isEmpty else {
            throw ServerVerificationError.encodingFailed
        }

        let signedTransactionInfo = signedTransactionInfo
        let signedRenewalInfo = signedRenewalInfo

        guard let token = TokenStore.token, !token.isEmpty else {
            throw ServerVerificationError.invalidResponse
        }

        guard let url = URL(string: "https://api.vsvault.io/api/subscriptions/verify") else { throw ServerVerificationError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "platform": "ios",
            "signed_transaction_info": signedTransactionInfo,
            "signed_renewal_info": signedRenewalInfo as Any? ?? NSNull()
        ]
        
        print("VERIFY BODY:", body)

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            throw ServerVerificationError.encodingFailed
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServerVerificationError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw ServerVerificationError.serverError(statusCode: http.statusCode) }

        // Try to decode server response; if unknown shape, treat 2xx as success
        if let decoded = try? JSONDecoder().decode(ServerVerificationResponse.self, from: data) {
            return decoded
        } else {
            return ServerVerificationResponse(success: true, message: nil)
        }
    }

    // MARK: - Purchase + Verify Convenience
    // NOTE: Verification will fail if JWS is missing (as designed)
    func purchaseAndVerifyPremium() async throws -> Bool {
        if let outcome = try await purchasePremium() {
            let result = try await verify(signedTransactionInfo: outcome.signedTransactionInfo, signedRenewalInfo: outcome.signedRenewalInfo)
            return result.success
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
        let success: Bool
        let message: String?
    }
    enum ServerVerificationError: Error {
        case invalidURL
        case encodingFailed
        case invalidResponse
        case serverError(statusCode: Int)
    }
}


import Foundation
import Combine

@MainActor
final class LoginViewRepository: ObservableObject {
    @Published var email: String = ""
    @Published var name: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    init() {}
}


//
//  TokenStore.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/25/26.
//
import KeychainAccess

struct TokenStore {
    private static let keychain = Keychain(service: "io.vsvault.app")

    static var token: String? {
        get { try? keychain.get("auth_token") }
        set {
            do {
                if let value = newValue {
                    try keychain.set(value, key: "auth_token")
                } else {
                    try keychain.remove("auth_token")
                }
            } catch {
                print("Keychain error:", error)
            }
        }
    }
}

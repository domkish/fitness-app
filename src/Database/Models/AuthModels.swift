//
//  AuthModels.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/24/26.
//

import Foundation

// Enum to track which auth screen to show
enum AuthStep {
    case login
    case register
    case resetPassword
    case token
    case password
    case success
    case done
}

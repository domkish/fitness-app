//
//  PremiumView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//

import SwiftUI

struct PremiumView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    
    var body: some View {
        let user = authCoordinator.currentUser!
        
        VStack(spacing: 20) {
            Text("Welcome, \(user.name)!")
                .font(.title)
                .bold()
            
            Text("This is where your main app content goes.")
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

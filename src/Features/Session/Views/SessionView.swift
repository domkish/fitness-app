//
//  SessionView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//

import SwiftUI

struct SessionView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Workout Routines")
                .font(.title)
                .bold()
            
            Text("This is where your main app content goes.")
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}


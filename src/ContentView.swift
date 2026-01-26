//
//  ContentView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/24/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authCoordinator: AuthCoordinator

    var body: some View {
        AuthCoordinatorView()
            .animation(.default, value: authCoordinator.currentStep)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background)
            .edgesIgnoringSafeArea(.all)
    }
}

// Preview for Xcode Canvas
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


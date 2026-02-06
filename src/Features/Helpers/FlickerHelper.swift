//
//  FlickerHelper.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/6/26.
//
import SwiftUI

/// A scroll view wrapper that avoids iOS 15+ tab bar flicker on pages with ScrollView
struct FlickerFreeScrollView<Content: View>: View {
    let content: () -> Content
    let showsIndicators: Bool
    let spacing: CGFloat

    init(showsIndicators: Bool = true, spacing: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.showsIndicators = showsIndicators
        self.spacing = spacing
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: showsIndicators) {
                LazyVStack(spacing: spacing, pinnedViews: []) {
                    content()

                    // Bottom spacer prevents content underlapping tab bar
                    Spacer()
                        .frame(height: geo.safeAreaInsets.bottom)
                }
                .frame(minHeight: geo.size.height, alignment: .top)
            }
        }
    }
}

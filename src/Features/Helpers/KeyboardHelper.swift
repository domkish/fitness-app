//
//  KeyboardHelper.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/3/26.
//

import SwiftUI

private struct KBButton: View {
    enum Content {
        case text(String)
        case system(String)
    }
    let content: Content
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Group {
                switch content {
                case .text(let t):
                    Text(t)
                        .font(.system(size: 22, weight: .semibold))
                case .system(let name):
                    Image(systemName: name)
                        .font(.system(size: 20, weight: .semibold))
                }
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct CustomNumericKeyboard: View {
    var onInsert: (String) -> Void
    var onDelete: () -> Void
    var onHide: () -> Void
    var onNext: () -> Void

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(["1","2","3","4","5","6","7","8","9"], id: \.self) { key in
                    KBButton(content: .text(key)) { onInsert(key) }
                }
                KBButton(content: .text(".")) { onInsert(".") }
                KBButton(content: .text("0")) { onInsert("0") }
                KBButton(content: .system("delete.left")) { onDelete() }
            }
            HStack(spacing: 8) {
                KBButton(content: .system("keyboard.chevron.compact.down")) { onHide() }
                KBButton(content: .text("Next")) { onNext() }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}


private struct KeyboardHost: ViewModifier {
    @Binding var isPresented: Bool
    let keyboard: () -> AnyView

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if isPresented {
                keyboard()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isPresented)
    }
}

extension View {
    func customNumericKeyboard(
        isPresented: Binding<Bool>,
        onInsert: @escaping (String) -> Void,
        onDelete: @escaping () -> Void,
        onHide: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) -> some View {
        self.modifier(KeyboardHost(isPresented: isPresented) {
            AnyView(
                CustomNumericKeyboard(
                    onInsert: onInsert,
                    onDelete: onDelete,
                    onHide: onHide,
                    onNext: onNext
                )
            )
        })
    }
}

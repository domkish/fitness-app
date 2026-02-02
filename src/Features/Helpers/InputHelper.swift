import SwiftUI
import Foundation

public struct LiveDecimalTextField: UIViewRepresentable {
    @Binding var displayText: String
    @Binding var digits: String
    let maxValue: Double

    public init(displayText: Binding<String>, digits: Binding<String>, maxValue: Double) {
        self._displayText = displayText
        self._digits = digits
        self.maxValue = maxValue
    }

    public func makeUIView(context: Context) -> UITextField {
        let tf = UITextField(frame: .zero)
        tf.keyboardType = .decimalPad
        tf.delegate = context.coordinator
        tf.textAlignment = .center
        tf.text = displayText
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tf
    }

    public func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != displayText { uiView.text = displayText }
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public final class Coordinator: NSObject, UITextFieldDelegate {
        let parent: LiveDecimalTextField
        init(_ parent: LiveDecimalTextField) { self.parent = parent }

        public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = textField.text ?? ""
            guard let r = Range(range, in: current) else { return true }
            let proposed = current.replacingCharacters(in: r, with: string)

            let rawDigits = proposed.filter { $0.isNumber }
            if rawDigits.isEmpty {
                parent.displayText = ""
                parent.digits = ""
                return true
            }

            var clamped = String(rawDigits)
            while !clamped.isEmpty {
                let v = (Double(clamped) ?? 0) / 10.0
                if v <= parent.maxValue { break }
                clamped.removeLast()
            }

            parent.digits = clamped
            let value = (Double(clamped) ?? 0) / 10.0
            parent.displayText = String(format: "%.1f", value)

            textField.text = parent.displayText
            let end = textField.endOfDocument
            textField.selectedTextRange = textField.textRange(from: end, to: end)
            return false
        }
    }
}

public struct InputWithSuffixDecimal: View {
    public let title: String?
    @Binding public var digits: String // raw digits only; if decimal == true, implicit 1 decimal place
    public let suffix: String
    public let maxValue: Double
    public let decimal: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @State private var displayText: String = ""

    public init(title: String? = nil,
                digits: Binding<String>,
                suffix: String,
                maxValue: Double,
                decimal: Bool = true) {
        self.title = title
        self._digits = digits
        self.suffix = suffix
        self.maxValue = maxValue
        self.decimal = decimal
    }

    public var body: some View {
        HStack(spacing: 8) {
            if decimal {
                LiveDecimalTextField(displayText: $displayText, digits: $digits, maxValue: maxValue)
                    .foregroundColor(themeManager.currentTheme.textDefault)
                    .padding(.vertical, 8)
                    .background(themeManager.currentTheme.formDefault)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.currentTheme.borderDefault, lineWidth: 1)
                    )
                    .cornerRadius(8)
                    .onAppear {
                        if digits.isEmpty {
                            displayText = ""
                        } else {
                            displayText = formatted(from: digits)
                        }
                    }
            } else {
                // Non-decimal: do not force decimals; accept digits as-is
                TextField("", text: $digits)
                    .keyboardType(.numberPad)
                    .foregroundColor(themeManager.currentTheme.textDefault)
                    .padding(.vertical, 8)
                    .multilineTextAlignment(.center)
                    .background(themeManager.currentTheme.formDefault)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.currentTheme.borderDefault, lineWidth: 1)
                    )
                    .cornerRadius(8)
            }

            Text(suffix)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(themeManager.currentTheme.surface)
                .clipShape(Capsule())
        }
    }

    private func formatted(from digits: String) -> String {
        guard !digits.isEmpty else { return "" }
        let value = (Double(digits) ?? 0) / 10.0
        return String(format: "%.1f", value)
    }
}


import SwiftUI
import Foundation

public struct LiveDecimalTextField: UIViewRepresentable {
    @EnvironmentObject var themeManager: ThemeManager
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
        tf.textColor = UIColor(themeManager.currentTheme.textDefault)
        tf.text = displayText
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // Add accessory toolbar with Done button to dismiss keyboard
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        // Apply theme-based colors
        toolbar.isTranslucent = false
        toolbar.barTintColor = UIColor(themeManager.currentTheme.formDefault)
        toolbar.backgroundColor = UIColor(themeManager.currentTheme.formDefault)
        toolbar.tintColor = UIColor(themeManager.currentTheme.textDefault)
        // Add a thin top border to mirror input borders
        let borderHeight: CGFloat = 1.0 / UIScreen.main.scale
        let topBorder = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: borderHeight))
        topBorder.backgroundColor = UIColor(themeManager.currentTheme.borderDefault)
        topBorder.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        toolbar.addSubview(topBorder)

        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Done", style: .done, target: context.coordinator, action: #selector(Coordinator.doneTapped))
        // Ensure the done button adopts theme tint
        done.tintColor = UIColor(themeManager.currentTheme.textDefault)
        toolbar.items = [flexible, done]
        tf.inputAccessoryView = toolbar
        return tf
    }

    public func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != displayText { uiView.text = displayText }
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public final class Coordinator: NSObject, UITextFieldDelegate {
        let parent: LiveDecimalTextField
        init(_ parent: LiveDecimalTextField) { self.parent = parent }

        public func textFieldDidBeginEditing(_ textField: UITextField) {
            // Show current display (reconstruct from digits if needed)
            let d = parent.digits
            if d.isEmpty {
                textField.text = ""
                parent.displayText = ""
            } else {
                let intPart = String(d.dropLast())
                let fracPart = String(d.suffix(1))
                // Always show the decimal part, even when it's .0
                let display = intPart + "." + fracPart
                textField.text = display
                parent.displayText = display
            }
        }

        public func textFieldDidEndEditing(_ textField: UITextField) {
            // Normalize to one decimal place on end editing
            let d = parent.digits
            if d.isEmpty {
                parent.displayText = ""
                textField.text = ""
                return
            }
            let intPart = String(d.dropLast())
            let fracPart = String(d.suffix(1))
            let display = intPart + "." + fracPart
            parent.displayText = display
            textField.text = display
        }

        public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = textField.text ?? ""
            guard let r = Range(range, in: current) else { return true }
            var proposed = current.replacingCharacters(in: r, with: string)

            // Allow only digits and at most one decimal point
            // Remove invalid characters
            let allowedSet = CharacterSet(charactersIn: "0123456789.")
            proposed = String(proposed.unicodeScalars.filter { allowedSet.contains($0) })

            // Enforce at most one decimal point
            if proposed.filter({ $0 == "." }).count > 1 {
                return false
            }

            // Split into integer and fraction
            let parts = proposed.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            var intPart = parts.count > 0 ? String(parts[0]) : ""
            var fracPart = parts.count == 2 ? String(parts[1]) : nil

            // Remove leading zeros unless the number is zero or we have a decimal prefix like ".x"
            if !intPart.isEmpty {
                intPart = String(intPart.drop { $0 == "0" })
                if intPart.isEmpty { intPart = "0" }
            }

            // Enforce max 3 integer digits when there's no decimal entered
            if fracPart == nil && intPart.count > 3 { return false }

            // Enforce at most 1 fractional digit
            if let f = fracPart {
                if f.count > 1 { return false }
            }

            // Build a normalized displayed string (during editing)
            var display = intPart
            if let f = fracPart { display += "." + f }

            // Compute numeric value to enforce maxValue
            let value: Double = Double(display) ?? 0
            if value > parent.maxValue { return false }

            // Update bindings: digits is raw implied-1-decimal digits (pad fractional 0 if absent)
            let fracDigit: String = (fracPart?.isEmpty == false) ? String(fracPart!.prefix(1)) : "0"
            let rawDigits = (intPart == "" ? "0" : intPart) + fracDigit
            parent.digits = rawDigits
            parent.displayText = display
            textField.text = display

            // Move caret to end
            let end = textField.endOfDocument
            textField.selectedTextRange = textField.textRange(from: end, to: end)
            return false
        }

        @objc func doneTapped() {
            // Dismiss the keyboard by resigning first responder on the active field
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
            
            if(suffix != ""){
                Text(suffix)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(themeManager.currentTheme.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
        }
    }

    private func formatted(from digits: String) -> String {
        guard !digits.isEmpty else { return "" }
        let value = (Double(digits) ?? 0) / 10.0
        return String(format: "%.1f", value)
    }
}


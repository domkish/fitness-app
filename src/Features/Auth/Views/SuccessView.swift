import SwiftUI

struct SuccessView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Success!")
                .font(.largeTitle).bold()
                .foregroundColor(.green)
            Text("Your operation was completed successfully.")
                .foregroundColor(.primary)
            Button("Continue") {
                // Action when Continue is tapped
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    SuccessView()
}

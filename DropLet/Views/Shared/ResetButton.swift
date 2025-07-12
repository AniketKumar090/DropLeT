import SwiftUI

struct ResetButton: View {
    @Binding var showConfirmationAlert: Bool
    @Binding var resetButtonTapped: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            showConfirmationAlert = true
            resetButtonTapped.toggle()
        }) {
            Text("Reset All Data")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.8))
                .cornerRadius(12)
        }
        .sensoryFeedback(.warning, trigger: resetButtonTapped)
    }
}

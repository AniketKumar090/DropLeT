import SwiftUI

struct SaveButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Save")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.6))
                .cornerRadius(8)
        }
    }
}

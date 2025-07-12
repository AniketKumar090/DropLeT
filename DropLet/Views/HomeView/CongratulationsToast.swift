import SwiftUI

struct CongratulationsToast: View {
    @Binding var isVisible: Bool
    
    var body: some View {
        VStack {
            if isVisible {
                Text("🎉 Goal Completed !!!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.00, green: 0.63, blue: 1.00).opacity(0.5))
                    .cornerRadius(25)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                            withAnimation {
                                isVisible = false
                            }
                        }
                    }
            }
        }
        .animation(.spring(), value: isVisible)
    }
}

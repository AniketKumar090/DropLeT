import SwiftUI

struct SplashScreenView: View {
    @Binding var isPresented: Bool
    @State private var scale = CGSize(width: 0.8, height: 0.8)
    @State private var systemImageOpacity = 0.0
    @State private var imageOpacity = 1.0
    @State private var maskHeight: CGFloat = 0
    @State private var opacity = 1.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ZStack {
                Image(systemName: "drop.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .opacity(imageOpacity)
                
                Image("Sphera")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .mask(
                        Rectangle()
                            .frame(width: 100, height: maskHeight)
                            .frame(maxHeight: 100, alignment: .top)
                    )
                    .opacity(systemImageOpacity)
            }
            .scaleEffect(scale)
        }
        .opacity(opacity)
        .onAppear {
            // Initial scale animation
            withAnimation(.easeInOut(duration: 1.5)) {
                scale = CGSize(width: 1, height: 1)
                systemImageOpacity = 1
            }
            
            // Mask animation to reveal Sphera image from top to bottom
            withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
                maskHeight = 100
            }
            
            // Final scale and fade out animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeIn(duration: 0.35)) {
                   // scale = CGSize(width: 50, height: 50)
                    opacity = 0
                }
            }
            
            // Toggle presentation state
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeIn(duration: 0.2)) {
                    isPresented.toggle()
                }
            }
        }
    }
}

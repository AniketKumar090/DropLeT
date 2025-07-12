import Foundation
import SwiftUI

struct ScannerShimmerView: View {
    @State private var yOffset: CGFloat = -200
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Static grid pattern
                GridPattern(density: 20)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                
                // Animated scanning section with dense grid
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 50)
                    .background(
                        GridPattern(density: 120) // Much denser grid
                            .stroke(Color.blue.opacity(0.4), lineWidth: 0.25)
                    )
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0),
                                Color.blue.opacity(0.4),
                                Color.blue.opacity(0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                   // .clipped()
                    .offset(y: yOffset)
                    .onAppear {
                        withAnimation(
                            .linear(duration: 2.0)
                            .repeatForever(autoreverses: false)
                        ) {
                            yOffset = geometry.size.height
                        }
                    }
            }
            .mask(
                RoundedRectangle(cornerRadius: 12)
                    .padding(.horizontal, 24)
            )
        }
    }
}

struct GridPattern: Shape {
    var density: CGFloat // Grid density parameter
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let gridSize = density // Grid cell size
        
        // Vertical lines
        stride(from: 0, through: rect.width, by: gridSize).forEach { x in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        // Horizontal lines
        stride(from: 0, through: rect.height, by: gridSize).forEach { y in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}

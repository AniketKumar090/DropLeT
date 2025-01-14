import SwiftUI

struct Challenge: View {
    @State private var currentIndex: Int = 35 * 18 - 1
    let totalCircles = 35 * 18
    
    let backgroundGradient = LinearGradient(colors: [Color.black, Color.clear],
        startPoint: .top, endPoint: .bottom)

    var percentageColored: Double {
            Double(totalCircles - (currentIndex + 1)) / Double(totalCircles) * 100
        }
    var textOffset: CGFloat {
           let currentColumn = (totalCircles - (currentIndex + 1)) / 35
           return currentColumn >= 1 ? -CGFloat(currentColumn * 35) : 0
       }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            backgroundGradient
           
            VStack(spacing: 4) {
                Spacer()
                  
                ForEach(0..<35) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<18) { column in
                            CircleView(
                                isHighlighted: (row * 18 + column) > currentIndex,
                                index: row * 18 + column
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.bottom, 2)
            .overlay {
                backgroundGradient
            }
            HStack {
             Spacer()
                HStack{
                    Text("  \(Int(percentageColored))")
                        .font(.system(size: 60))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("%  ")
                        .font(.system(size: 25))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.top)
                } .background{
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black)
                }
                        
                Spacer()
            }
                .padding(.bottom,25)
                .offset(y: textOffset)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: textOffset)
                                
            
            Button(action: {
                if currentIndex >= 0 {
                    currentIndex -= 10
                }
            }) {
                Image(systemName: "plus")
                    .padding()
                    .foregroundColor(.white)
                    .background(.cyan)
                    .cornerRadius(30)
            }
            .shadow(color: .cyan, radius: 15, y: 5)
            .padding(.trailing, 25)
            .padding(.bottom, 25)
        }
        .ignoresSafeArea()
    }
}

struct CircleView: View {
    let isHighlighted: Bool
    let index: Int
    
    var body: some View {
        Circle()
            .foregroundStyle(isHighlighted ? Color.randomBlue() : Color.randomGray())
    }
}

extension Color {
    static func randomGray() -> Color {
        return .init(
            red: 0.33 + .random(in: -0.05...0.05),
            green: 0.33 + .random(in: -0.05...0.05),
            blue: 0.33 + .random(in: -0.05...0.05)
        )
    }
    static func randomBlue() -> Color {
        return .init(
            red: 0.1 + .random(in: -0.05...0.05),
            green: 0.1 + .random(in: -0.05...0.05),
            blue: 0.8 + .random(in: -0.5...0.2)
        )
    }
    static func randomGreen() -> Color {
        return .init(
            red: 0.1 + .random(in: -0.05...0.05),
            green: 0.8 + .random(in: -0.1...0.1),
            blue: 0.1 + .random(in: -0.05...0.05)
        )
    }
}

#Preview {
    Challenge()
}

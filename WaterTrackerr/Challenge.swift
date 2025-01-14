import SwiftUI
import Foundation

struct CircleData: Identifiable {
    let id: Int
    var drinkType: DrinkType?
}

@Observable class DrinkViewModel {
    var circles: [CircleData]
    var selectedType: DrinkType = .water
    var totalDrinks: Int = 0
    
    init() {
        // Initialize all circles as empty (not filled)
        self.circles = Array(0..<(45 * 24)).map { CircleData(id: $0, drinkType: nil) }
    }
    
    func fillCircles(count: Int, with drinkType: DrinkType) {
        // Find the first empty circle from the end
        if let firstEmptyIndex = circles.lastIndex(where: { $0.drinkType == nil }) {
            for i in 0..<count {
                let index = firstEmptyIndex - i
                if index >= 0 {
                    circles[index].drinkType = drinkType
                    totalDrinks += 1
                }
            }
        }else {
            totalDrinks += count
        }
    }
}

struct Challenge: View {
    @State var viewModel: DrinkViewModel
    let totalCircles = 30 * 24
    
    var percentageFilled: Double {
        Double(viewModel.totalDrinks) / Double(totalCircles) * 100
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack(alignment: .bottomTrailing) {
                    LinearGradient.gradientBackground()
              
                    VStack(spacing: 4) {
                        Spacer()
                        
                        ForEach(0..<45) { row in
                            HStack(spacing: 2) {
                                ForEach(0..<24) { column in
                                    let index = row * 24 + column
                                    CircleView(
                                        circleData: viewModel.circles[index]
                                    )
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.black,
                                Color.black.opacity(0.8),
                                Color.clear,
                                Color.clear,
                                Color.clear,
                                Color.clear,
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                   
                    VStack {
                        HStack {
                            Spacer()
                            HStack{
                                Text("  \(Int(percentageFilled))")
                                    .font(.system(size: 60))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("%  ")
                                    .font(.system(size: 25))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.top)
                            }
                            Spacer()
                        }
                        .padding(.top, geometry.size.height * 0.15)
                        Spacer()
                    }
                    
                    NavigationLink(destination: AddCircleView(viewModel: viewModel).navigationBarBackButtonHidden(true)){
                        Image(systemName: "plus")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .padding(25)
                            .foregroundColor(.white)
                            .background(.black)
                            .cornerRadius(50)
                            .shadow(color: .black, radius: 15, y: 5)
                    }
                    .padding(30)
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
                }
                .ignoresSafeArea()
            }
        }
    }
}
struct AddCircleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var fillPercentage: CGFloat = 0.05
    let totalCircles = 15 * 15
    @State private var selectedType: DrinkType = .water
    @State var viewModel: DrinkViewModel
    
    var body: some View {
        ZStack {
            LinearGradient.gradientBackground()
                .edgesIgnoringSafeArea(.all)
            VStack(alignment: .leading){
               
                HStack{
                    Text("\(Int(fillPercentage * 100)*10)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                       
                       
                    Text("ml")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top,5)
                        .offset(x:-10)
                }.padding(.leading, 70)
                HStack {
                    
                    ZStack {
                        
                        Capsule()
                            .fill( LinearGradient.gradientBackground())
                            .frame(width: 100, height: 300)
                            .shadow(color: .gray, radius: 10, y: 5)
                        VStack{
                            ForEach(0..<15) { row in
                                HStack(spacing: 1) {
                                    ForEach(0..<15) { column in
                                        CircleView(
                                            circleData: CircleData(
                                                id: row * 15 + column,
                                                drinkType: (totalCircles - (row * 15 + column) - 1) < Int(fillPercentage * CGFloat(totalCircles)) ? selectedType : nil
                                            )
                                        )
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                        }.mask{
                            Capsule()
                                .frame(width: 100, height: 300)
                        }
                        .animation(.easeInOut(duration: 0.5), value: fillPercentage)
                    }
                    VStack{
                        Text("Drinks")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.trailing,80)
                        ForEach(DrinkType.allCases, id: \.self) { type in
                            HStack(spacing: 8) {
                                Image(systemName: type.icon)
                                    .font(.title2)
                                    .foregroundColor(type.color)
                                Text(type.rawValue.capitalized)
                                    .font(.caption)
                            }
                            .frame(width: 100, height: 50)
                            .background {
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(selectedType == type ? .gray.opacity(0.6) : .gray.opacity(0.2))
                            }
                            .foregroundColor(selectedType == type ? .white : .primary)
                            .padding(.trailing,80)
                            .shadow(color: type.color, radius: 15, y: 5)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedType = type
                                }
                            }
                        }
                    }
                }
                
                Slider(value: $fillPercentage, in: 0.0...1.0, step: 0.05)
                    .padding()
                    .tint(selectedType.color)
             
            }
            VStack {
                Spacer()
                Button(action: {
                    let circlesToFill = Int(fillPercentage * CGFloat(totalCircles))
                    viewModel.fillCircles(count: circlesToFill, with: selectedType)
                    dismiss()
                }) {
                    Text("Add Drink")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.5))
                        .cornerRadius(15)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            
        }
    }
}

struct CircleView: View {
    let circleData: CircleData
    
    var body: some View {
        Circle()
            .foregroundStyle(circleData.drinkType.map(getHighlightColor) ?? Color.randomMetallicGray())
            .animation(.easeInOut(duration: 0.2), value: circleData.drinkType != nil)
    }
    
    private func getHighlightColor(_ drinkType: DrinkType) -> Color {
        switch drinkType {
        case .water:
            return Color(hue: 0.583 + .random(in: -0.1...0.1), saturation: 0.85 , brightness: 0.68)
        case .tea:
            return Color.randomGreen()
        case .coffee:
            return Color.randomBrown()
        case .soda:
            return Color.randomPink()
        }
    }
}

extension LinearGradient {
    static func gradientBackground() -> LinearGradient {
        return LinearGradient(gradient: Gradient(colors: [Color.black, Color.black]), startPoint: .top, endPoint: .bottom)
    }
}

extension Color {
    static func randomMetallicGray() -> Color {
        let baseGray = 0.5 + .random(in: -0.1...0.1)  // A midpoint gray base
        let variation = 0.1 + .random(in: -0.05...0.05)  // Slightly varying component

        return .init(
            red: baseGray + variation,
            green: baseGray + variation,
            blue: baseGray + variation
        )
    }
    
    static func randomBlue() -> Color {
        return .init(
            red: 0.1 + .random(in: -0.2...0.2),
            green: 0.1 + .random(in: -0.2...0.2),
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
    static func randomBrown() -> Color {
        return .init(
            red: 0.6 + .random(in: -0.05...0.25),
            green: 0.4 + .random(in: -0.1...0.2),
            blue: 0.2 + .random(in: -0.05...0.15)
        )
    }
        
    static func randomPink() -> Color {
        return .init(
            red: 1.0 + .random(in: -0.1...0.0),
            green: 0.4 + .random(in: -0.1...0.1),
            blue: 0.7 + .random(in: -0.1...0.1)
        )
    }
}

#Preview {
    Challenge(viewModel: DrinkViewModel())
}

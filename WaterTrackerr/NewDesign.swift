import SwiftUI

struct NewDesign: View {
    @State private var remainingAmount = 821.0
    @State private var percentage = 74
    
    var body: some View {
        GeometryReader { geometry in
            
            let screenWidth = geometry.size.width
            let circleCountPerRow: CGFloat = 15
            let totalPadding: CGFloat = 64
            let availableWidth = screenWidth - totalPadding
            let dynamicSpacing = availableWidth / circleCountPerRow - 4
            
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Spacer()
                    HStack(alignment: .lastTextBaseline) {
                        Text("\(percentage)%")
                            .font(.system(size: 32, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.leading, 32)
                        Spacer()
                        Text("\(Int(remainingAmount))")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            
                        Text("ml left")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.trailing, 32)
                        
                    }.padding(.bottom,42)
                    
                   
                    
                    VStack(spacing: 18) {
                        ForEach(0..<23) { row in
                            HStack(spacing: dynamicSpacing) {
                                ForEach(0..<15) { column in
                                    Circle().fill(Color.white)
                                        .frame(width: 4)
                            
                                }
                            }
                        }
                    }
                    
                    
                    
                    HStack {
                        Button(action: {
                            
                        }) {
                            Image(systemName: "drop.fill")
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Circle().fill(Color.white.opacity(0.07)))
                        }
                        .padding(.trailing, 44)
                        .padding(.leading, 32)
                        
                        Button(action: {
                            
                        }) {
                            Text("Add")
                                .foregroundColor(.white)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 54)
                                .background(RoundedRectangle(cornerRadius: 24.5)
                                    .fill(Color(red: 0/255, green: 161/255, blue: 255/255)).opacity(0.5))
                                .frame(width: 140, height: 50)
                        }
                        
                        Button(action: {
                           
                        }) {
                            Image("Tabview")
                                .foregroundColor(.white)
                                .padding(19)
                                .background(Circle().fill(Color.white.opacity(0.07)))
                        }
                        .padding(.trailing, 32)
                        .padding(.leading, 44)
                    }
                    .padding(.top, 48)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NewDesign()
    }
}

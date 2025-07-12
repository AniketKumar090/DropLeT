import SwiftUI

struct CustomSegmentedControl: View {
    @Binding var preselectedIndex: Int
    var options: [String]
    // this color is coming theme library
    let color = Color.gray

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id:\.self) { index in
                ZStack {
                    Rectangle()
                        .fill(color.opacity(0.2))

                    Rectangle()
                        .fill(color)
                        .cornerRadius(20)
                        .padding(2)
                        .opacity(preselectedIndex == index ? 0.2 : 0.01)
                        .onTapGesture {
                                withAnimation(.interactiveSpring()) {
                                    preselectedIndex = index
                                }
                            }
                }
                .overlay(
                    Text(options[index])
                        .font(.system(size: 16,weight: .regular,design: .monospaced))
                )
            }
        }
        .frame(height: 40)
        .cornerRadius(20)
    }
}

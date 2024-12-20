import SwiftUI

struct AddDrinkView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAmount: Double = 250
    @State private var selectedType: DrinkType = .water
    @State private var animateContent = false
    let onSave: (Double, DrinkType) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                 VStack(spacing: 15) {
                    Image(systemName: selectedType.icon)
                        .font(.system(size: 45))
                        .foregroundColor(selectedType.color)
                        .opacity(animateContent ? 1 : 0)
                        .scaleEffect(animateContent ? 1 : 0.5)
                    
                    Text("\(Int(selectedAmount))ml")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 25)
                .background {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(.indigo.opacity(0.1))
                }
                .padding(.horizontal)
                
               
                VStack(alignment: .leading, spacing: 15) {
                    Text("Select Drink Type")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .opacity(0.8)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(DrinkType.allCases, id: \.self) { type in
                                VStack(spacing: 8) {
                                    Image(systemName: type.icon)
                                        .font(.title2)
                                        .foregroundColor(type.color)
                                    Text(type.rawValue.capitalized)
                                        .font(.caption)
                                }
                                .frame(width: 80, height: 80)
                                .background {
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(selectedType == type ? .indigo : .gray.opacity(0.1))
                                }
                                .foregroundColor(selectedType == type ? .white : .primary)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedType = type
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("Amount")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .opacity(0.8)
                    
                    VStack(spacing: 8) {
                        Slider(value: $selectedAmount, in: 50...1000, step: 50)
                            .tint(.indigo)
                        
                        HStack {
                            Text("50ml")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("1000ml")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.gray.opacity(0.1))
                    }
                }
                .padding(.horizontal)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                
                Spacer()
                
                HStack(spacing: 15) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.gray.opacity(0.1))
                            }
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: {
                        onSave(selectedAmount, selectedType)
                        dismiss()
                    }) {
                        Text("Save")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.indigo)
                            }
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
            }
            .padding(.vertical)
            .navigationTitle("Add Drink")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                withAnimation(.spring(response: 0.8)) {
                    animateContent = true
                }
            }
        }
    }
}


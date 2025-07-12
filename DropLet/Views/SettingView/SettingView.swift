import SwiftUI

struct SettingView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: DrinkViewModel
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("wavesEnabled") private var waveMotion = true
    @State private var temporaryGoal: String = ""
    @State private var showInvalidGoalAlert = false
    @State private var showConfirmationAlert = false
    @State private var resetbuttonTapped = false
    @FocusState private var isGoalFieldFocused: Bool
    @State private var showCongratulations = false
    @State private var showAlert = false
    @State private var showError = false
    @State private var alertMessage = ""
    @StateObject private var notificationManager = NotificationManager()
    @State private var quickSelections: [QuickSelection] = [
        QuickSelection(icon: "wineglass.fill", label: "Half Glass", volume: 150, isSelected: true),
        QuickSelection(icon: "cup.and.saucer.fill", label: "Cup", volume: 200, isSelected: true),
        QuickSelection(icon: "bubbles.and.sparkles.fill", label: "Glass", volume: 250, isSelected: true),
        QuickSelection(icon: "waterbottle.fill", label: "Bottle", volume: 500, isSelected: true),
        QuickSelection(icon: "drop.fill", label: "Small Sip", volume: 50, isSelected: true),
        QuickSelection(icon: "drop.triangle.fill", label: "Medium Sip", volume: 100, isSelected: true),
        QuickSelection(icon: "drop.circle.fill", label: "Large Sip", volume: 350, isSelected: true),
        QuickSelection(icon: "flame.fill", label: "Shot", volume: 30, isSelected: true),
        QuickSelection(icon: "mug.fill", label: "Mug", volume: 400, isSelected: false),
        QuickSelection(icon: "thermometer.snowflake", label: "Cold Drink", volume: 200, isSelected: false),
        QuickSelection(icon: "thermometer.sun.fill", label: "Hot Drink", volume: 250, isSelected: false),
        QuickSelection(icon: "staroflife.fill", label: "Energy Drink", volume: 300, isSelected: false),
        QuickSelection(icon: "leaf.fill", label: "Herbal Tea", volume: 200, isSelected: false),
        QuickSelection(icon: "cloud.fill", label: "Smoothie", volume: 350, isSelected: false),
        QuickSelection(icon: "drop.circle.fill", label: "Juice", volume: 250, isSelected: false),
        QuickSelection(icon: "fork.knife", label: "Soup", volume: 300, isSelected: false),
        QuickSelection(icon: "snowflake", label: "Ice Water", volume: 150, isSelected: false),
        QuickSelection(icon: "sun.max.fill", label: "Lemonade", volume: 200, isSelected: false),
        QuickSelection(icon: "moon.fill", label: "Nightcap", volume: 50, isSelected: false),
        QuickSelection(icon: "heart.fill", label: "Health Drink", volume: 100, isSelected: false)
    ]
    
    // State variables to track section expansion
    @State private var isDailyGoalExpanded = false
    @State private var isPreferencesExpanded = false
    @State private var isQuickSelectionsExpanded = false
    @State private var isAboutExpanded = false

    private func handleSelectionChange(for selection: QuickSelection) {
        let currentlySelected = quickSelections.filter { $0.isSelected }.count
        if !selection.isSelected && currentlySelected >= 8 {
            alertMessage = "You can only select up to 8 items. Please deselect an item before selecting a new one."
            showAlert = true
            showError.toggle()
            return
        }
        if let index = quickSelections.firstIndex(where: { $0.id == selection.id }) {
            quickSelections[index].isSelected.toggle()
        }
    }

    var body: some View {
        ZStack{
            VStack{
                // Header
                HStack(alignment: .lastTextBaseline) {
                    Text("Settings")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        viewModel.chartViewEntry = false
                        isGoalFieldFocused = false
                        dismiss()
                        isDailyGoalExpanded = false
                        isPreferencesExpanded = false
                        isAboutExpanded =  false
                        isQuickSelectionsExpanded = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .imageScale(.large)
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
            
            
            
            VStack(alignment: .leading,spacing: 24) {
                
                Spacer().frame(height: 30)
                Section(header: Text("General")
                    .foregroundColor(.gray)
                    .textCase(nil)
                    .font(.system(size: 16))
                    .padding(.leading)) {
                        // Daily Goal Section
                        SectionHeader(title: "Daily Goal", icon: "target", isExpanded: $isDailyGoalExpanded)
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    isDailyGoalExpanded.toggle()
                                    isPreferencesExpanded = false
                                    isQuickSelectionsExpanded = false
                                    isAboutExpanded = false
                                }
                            }
                        if isDailyGoalExpanded {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 12) {
                                        TextField(viewModel.useOunces ? "Enter goal (oz)" : "Enter goal (ml)", text: $temporaryGoal)
                                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                                            .keyboardType(.decimalPad)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.white.opacity(0.15))
                                            .cornerRadius(12)
                                            .focused($isGoalFieldFocused)
                                        Button(action: {
                                            if let newGoal = Int(temporaryGoal), newGoal > 0 {
                                                viewModel.goal = viewModel.useOunces ? Int(viewModel.ozToMl(Double(newGoal))) : newGoal
                                                temporaryGoal = ""
                                                isGoalFieldFocused = false
                                                dismiss()
                                                withAnimation(.easeInOut(duration: 1.5)) {
                                                    viewModel.chartViewEntry = false
                                                }
                                            } else {
                                                showInvalidGoalAlert = true
                                                showCongratulations.toggle()
                                            }
                                        }) {
                                            Text("Set")
                                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 24)
                                                .padding(.vertical, 12)
                                                .background(Color.blue.opacity(0.6))
                                                .cornerRadius(12)
                                        }.sensoryFeedback(.error, trigger: showCongratulations)
                                    }
                                    Text("Current goal: \(viewModel.useOunces ? Int(viewModel.mlToOz(Double(viewModel.goal))) : viewModel.goal) \(viewModel.useOunces ? "oz" : "ml")")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.08).onTapGesture { isGoalFieldFocused = false })
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // Preferences Section
                        SectionHeader(title: "Preferences", icon: "slider.horizontal.3", isExpanded: $isPreferencesExpanded)
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    isDailyGoalExpanded = false
                                    isPreferencesExpanded.toggle()
                                    isQuickSelectionsExpanded = false
                                    isAboutExpanded = false
                                }
                            }
                        if isPreferencesExpanded {
                            VStack(alignment: .leading, spacing: 16) {
                                SettingsToggle(isOn: $notificationsEnabled,
                                               icon: "bell.fill",
                                               title: "Notifications",
                                               onChange: { newValue in
                                    notificationManager.toggleNotifications(newValue)
                                }).onTapGesture { isGoalFieldFocused = false }
                                SettingsToggle(isOn: $viewModel.useOunces,
                                               icon: "scalemass.fill",
                                               title: "Use Ounces").onTapGesture { isGoalFieldFocused = false }
                            }
                            .padding()
                            .background(Color.white.opacity(0.08).onTapGesture { isGoalFieldFocused = false })
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // Quick Selections Section
                        SectionHeader(title: "Quick Selections", icon: "bolt.fill", isExpanded: $isQuickSelectionsExpanded)
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    isDailyGoalExpanded = false
                                    isPreferencesExpanded = false
                                    isQuickSelectionsExpanded.toggle()
                                    isAboutExpanded = false
                                }
                            }
                        if isQuickSelectionsExpanded {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Select from the list below")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    Spacer()
                                    SaveButton {
                                        let selectedCount = quickSelections.filter { $0.isSelected }.count
                                        if selectedCount != 8 {
                                            alertMessage = "Please select exactly 8 items"
                                            showError.toggle()
                                            showAlert = true
                                        } else {
                                            viewModel.selectedQuickSelections = quickSelections.filter { $0.isSelected }
                                            viewModel.chartViewEntry = false
                                            isGoalFieldFocused = false
                                            dismiss()
                                        }
                                    }
                                }
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHGrid(rows: Array(repeating: GridItem(.flexible()), count: 2),
                                              alignment: .center,
                                              spacing: 10) {
                                        ForEach($quickSelections) { $selection in
                                            QuickSelectionButton(selection: selection) {
                                                handleSelectionChange(for: selection)
                                            }
                                        }
                                    }
                                }
                                .frame(height: 150)
                            }
                            .padding()
                            .background(Color.white.opacity(0.08).onTapGesture {
                                isGoalFieldFocused = false
                            })
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        SectionHeader(title: "About", icon: "info.circle", isExpanded: $isAboutExpanded)
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    isDailyGoalExpanded = false
                                    isPreferencesExpanded = false
                                    isAboutExpanded.toggle()
                                    isQuickSelectionsExpanded = false
                                }
                            }
                        
                        if isAboutExpanded {
                            ScrollView{
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Why Hydration is Important")
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    
                                    Text("""
                                        Staying hydrated is crucial for maintaining overall health. Water helps regulate body temperature, \
                                        supports digestion, flushes out toxins, and keeps your skin healthy. Proper hydration also improves \
                                        cognitive function, boosts energy levels, and prevents fatigue.
                                        """)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray)
                                    
                                    Text("How to Use This App")
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    
                                    Text("""
                                        This app helps you track your daily water intake and reminds you to stay hydrated. You can set a daily hydration goal, log your drinks using quick selections or even scan your drinks barcodes for custom volumes, and view insights into your drinking habits. The app will reset your data at midnight every day to help you start fresh.
                                        """)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray)
                                }
                                
                                
                            }
                            .scrollIndicators(.hidden)
                            .padding()
                            .frame(maxHeight: 425)
                            .background(Color.white.opacity(0.08).onTapGesture { isGoalFieldFocused = false })
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                    }
                // Other Section
                Section(header: Text("Other")
                    .foregroundColor(.gray)
                    .textCase(nil)
                    .font(.system(size: 16))
                    .padding(.leading)) {
                        
                        // Write a Review
                        HStack {
                            Text("Write A Review")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            
                            
                            Spacer()
                            Button(action: {
                                // Handle review action
                            }) {
                                Image(systemName: "star")
                                    .foregroundColor(.gray)
                                    .font(.title3)
                            }
                        } .padding(.horizontal)
                        // Share App
                        
                        HStack {
                            Text("Share App")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: {
                                // Handle share action
                            }) {
                                
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.gray)
                                    .font(.title3)
                            }
                        } .padding(.horizontal)
                    }
                Spacer()
                
            }.padding(.bottom,40)
            
            
            VStack{
                Spacer()
                HoldDownButton(text: "Delete All Recorded Data",duration: 2, background: Color.gray.opacity(0.5), loadingTint: .red){
                    showConfirmationAlert = true
                    resetbuttonTapped.toggle()
                    
                }.padding(.horizontal)
                .sensoryFeedback(.warning, trigger: resetbuttonTapped)
                
            }
        }
       
        .background(Color.black.ignoresSafeArea()
            .onTapGesture {
                isGoalFieldFocused = false
            })
        .ignoresSafeArea(.keyboard)
        .alert("Invalid Goal", isPresented: $showInvalidGoalAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enter a valid number greater than 0")
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }.sensoryFeedback(.error, trigger: showError)
        .alert("Are you sure?", isPresented: $showConfirmationAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                viewModel.chartViewEntry = false
                viewModel.reset()
            }
        }
    }
}

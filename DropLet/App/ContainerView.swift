import SwiftUI

struct ContainerView: View {
    @State private var isSplashScreenViewPresented = true
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var drinkViewModel = DrinkViewModel()
    
    var body: some View {
        if !isSplashScreenViewPresented {
            Home(viewModel: drinkViewModel)
                .onAppear {
                    notificationManager.scheduleNotifications()
                }
        } else {
            SplashScreenView(isPresented: $isSplashScreenViewPresented)
        }
    }
}

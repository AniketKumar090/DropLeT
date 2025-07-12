import SwiftUI

struct ContainerView: View {
    @State private var isSplashScreenViewPresented = true
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var midnightResetManager = MidnightResetManager()
    
    var body: some View {
        if !isSplashScreenViewPresented{
            Home(viewModel: DrinkViewModel()).environmentObject(midnightResetManager)
                .onAppear {
                    notificationManager.scheduleNotifications()
                }
        }else {
            SplashScreenView(isPresented: $isSplashScreenViewPresented)
        }
    }
}

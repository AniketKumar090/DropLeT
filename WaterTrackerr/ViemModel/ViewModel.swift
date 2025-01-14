import Foundation
import SwiftUI

class ViewModel: ObservableObject {
    @Published var pet: Pet
    private let repository = PetRepository()
    
    init() {
        pet = repository.loadData()
    }
    func saveData() {
        objectWillChange.send()
        repository.saveData(pet: pet)
        print("saved")
    }
    func giveWater() {
        pet.lastDrink = Date()
        saveData()
        print("gg")
    }
}

# DropLeT — A Beautiful Hydration Tracking App

**DropLeT** is a sleek, modern hydration tracking app built using **SwiftUI**, designed with a focus on **clean architecture**, **smooth navigation**, and **delightful animations**. It helps users track their daily water intake with features like goal setting, custom drink logging, barcode scanning for product lookup, data visualization via charts, and smart notifications.

## 🌟 Key Features

- 💧 **Daily Water Intake Tracking**
- 🎯 **Customizable Daily Goals (ml/oz)**
- 📱 **Barcode Scanning (via AVFoundation + OpenFoodFacts API)**
- 📊 **Progress Visualization Using Apple's Charts Framework**
- 🕒 **Midnight Data Reset**
- 🔔 **Scheduled Hydration Reminders**
- 🌙 **Dark Mode Support**
- ⚙️ **Settings to Customize Quick Drink Selections**

---

## 🛠️ Technologies Used

| Technology             | Purpose |
|------------------------|---------|
| **SwiftUI**            | Declarative UI framework for building the entire interface. |
| **Combine**            | Reactive programming for state management and data flow. |
| **UserDefaults**       | Lightweight persistence for storing user preferences and drink records. |
| **AVFoundation**       | Real-time barcode scanning integration. |
| **UserNotifications**  | Scheduling daily reminders and midnight reset alerts. |
| **Charts**             | Visualizing hydration trends (hourly, daily, weekly). |
| **Codable**            | Encoding/decoding of drink records and model objects. |
| **URLSession**         | REST API communication for product lookup via OpenFoodFacts. |

---

## 📦 Architecture Overview

The app follows a **clean MVVM architecture**:

### ✅ Models
- `DrinkRecords`: Codable model representing each drink logged.
- `CircleData`: Tracks filled circles in the progress visualization.
- `DrinkType`: Enum for different drink types (water, tea, coffee, soda).
- `QuickSelection`: Represents quick volume buttons.
- `OpenFoodFactsResponse`: Response model for product lookup API.

### 🧠 ViewModel (`DrinkViewModel`)
- Centralized business logic and data handling:
  - Manages hydration goals, consumption, and progress.
  - Handles keyboard input, animations, and persistence.
  - Generates mock data if no drinks are logged yet.

### 👁 Views
- Modular SwiftUI views such as:
  - `HomeView`
  - `AddView` (with barcode scanner)
  - `ChartView`
  - `SettingView`
  - `CongratulationsToast`
  - `DrinkLogSheet`

---

## 🔍 Highlights

### 🎨 Custom UI Components
- **Animated Circle Grid**: Visual representation of daily hydration progress.
- **Custom Segmented Control**: For switching between chart timeframes.
- **Hold-to-Delete Button**: With haptics and animation feedback.
- **Shimmer Effects**: Used during scanning or loading states.
- **Pulse Animation**: In the scanner overlay.

### 📊 Data Visualization
- Uses Apple's **Charts framework** to show:
  - Hourly
  - Daily
  - Weekly hydration trends
- Dynamic Y-axis scaling based on current dataset.

### 📷 Barcode Scanner Integration
- Integrated with **OpenFoodFacts API** to extract product volumes from barcodes.
- Includes cooldown mechanism to prevent duplicate scans.

### 🔄 Midnight Reset
- Automatically resets hydration data at midnight.
- Uses `Timer` and `NotificationCenter` to update the UI accordingly.

---

## 🚀 How to Run

### Prerequisites
- Xcode 15+
- iOS 16+ simulator or device

### Steps
1. Clone the repo:
```bash
git clone https://github.com/AniketKumar090/DropLeT.git
```

2. Open the `.xcodeproj` file in Xcode.

3. Select a simulator or connected device.

4. Hit the **Run** button.

> **Note**: Some features like camera access require testing on a real device.

---

## 📸 Screenshots

<div align="center">
  <img src="https://github.com/user-attachments/assets/904f0799-e588-4fd2-91be-1a512c581201" alt="Home Screen" width="150" height="325" />
  <img src="https://github.com/user-attachments/assets/45e4c304-455e-46db-8e49-30d3bc0b8d2d" alt="Add Drink" width="150" height="325" />
  <img src="https://github.com/user-attachments/assets/a2f3f8ca-c0f9-474d-940d-f10e07feab62" alt="Charts View" width="150" height="325" />
  <img src="https://github.com/user-attachments/assets/161ff60b-916b-4f47-a15f-c859a31d23a4" alt="Scanner" width="150" height="325" />
  <img src="https://github.com/user-attachments/assets/ad0c4e34-7962-46ac-af31-67caf5edfed4" alt="Settings" width="150" height="325" />
</div>

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📜 License

This project is available under the **MIT License** – see the [LICENSE](LICENSE) file for details.

---

## 📬 Contact

**Aniket Kumar**

- GitHub: [@AniketKumar090](https://github.com/AniketKumar090)
- Email: kumaraniket009@gmail.com
- LinkediIn:: [Aniket Kumar](https://www.linkedin.com/in/aniket-kumar-06348a227/)

---

## 🙏 Acknowledgments

- Thanks to [OpenFoodFacts](https://world.openfoodfacts.org/) for their open API
- Apple's Charts framework for beautiful data visualization
- The SwiftUI community for inspiration and best practices

---

**Thank you for checking out DropLeT!** This app was crafted with care to showcase modern SwiftUI techniques, thoughtful UX, and modular architecture. If you found it useful or inspiring, give it a ⭐ and share it with others who might enjoy it too!

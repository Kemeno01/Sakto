# Sakto (Spent-To-Sawa)

**Sakto** is an offline-first personal budgeting, expense checklist, and group bill-splitting mobile app built with Flutter (using Philippine Peso `₱`). It helps you track your cash on hand, organize purchases by tags, split shared bills with friends, and review your spending trends—all saved locally on your device.

---

## Features

### 1. Home — Cash on Hand & Daily History
- **Live Budget Overview:** Tracks your **Cash on Hand**, total spent (counting only *your* share on split tags), and remaining balance with a visual progress bar.
- **Cash Tracking:** Update your cash on hand anytime; increases are automatically recorded as income for analytics.
- **Save Day:** Snapshot your checked items into daily history so you can review past spending.
- **Calendar & Reuse:** Open the calendar to inspect any saved day's breakdown, or tap **Reuse** to copy a past day's items back into your active list.
- **Reset Data:** Wipe all local items, tags, history, and settings from the profile/user sheet if you want a fresh start.

### 2. Lists — Tag-Based Expense Checklist
- **Color-Coded Tags:** Create, rename, and delete tags (e.g., *Groceries*, *Food*, *Bills*, *Trip*) and optionally assign a separate cash budget per tag.
- **Interactive Item Checklist:** Add items with name, price, and quantity, then check/uncheck items to include or exclude them from your live total.
- **Item Actions:** Edit item details, duplicate items, move items between tags, or delete them.
- **Tag Filtering:** Tap one or more tags to view their combined total and per-tag budget cap.

### 3. Split — Group Bill Splitter
- **Per-Tag Groups:** Turn any tag into a shared bill by adding people (`Me` + friends).
- **Two Split Modes:**
  - **Equal Split:** Divides checked items evenly across everyone in the group.
  - **Custom / Per-Item Split:** Assign specific owners to individual items.
- **Discounts & Fees:** Add discounts or extra fees (e.g., delivery or service charges), automatically distributed proportionally across each person's subtotal.
- **Payment & Change Tracking:** Track who has paid, record the exact cash handed to you, and mark whether change has been returned.
- **Accurate Personal Totals:** Only *your* share from a split tag counts toward your overall spending on the Home screen.

### 4. Analytics — Spending & Trend Insights
- **Visual Charts:** View bar charts and donut category breakdowns of your spending.
- **Flexible Date Ranges:** Filter by **Today**, **7 Days**, **30 Days**, **This Month**, **Last Month**, **3 Months**, **This Year**, or a **Custom Date Range**.
- **Period Comparison:** Toggle **Compare with previous period** to see how your spending changes over time.

---

## How to Use the App (Quick Walkthrough)

1. **Set Your Cash on Hand:** On the **Home** tab, tap your cash balance to enter how much money you have on hand.
2. **Create Tags:** Go to **Lists** (or open the tags manager) and add categories like *Food*, *Transport*, or *Group Dinner*.
3. **Add & Check Items:** Tap the center **`+`** button to add items with price and quantity. Check items off as you spend to update your live total.
4. **Split Shared Expenses (Optional):** Open the **Split** tab, choose a tag, pick **Equal** or **Custom** mode, add the people involved, and track payments/change.
5. **Save Your Day:** Once done for the day, save your checked items from the **Home** tab so they appear in **Calendar History** and **Analytics**.
6. **Review Trends:** Open the **Analytics** tab to inspect where your money goes across any date range.

---

## Tech Stack

- **Framework:** [Flutter](https://flutter.dev/) (Dart SDK `^3.13.4`)
- **State Management:** `ChangeNotifier` (`AppState` in `lib/main.dart`)
- **Local Storage:** [`shared_preferences`](https://pub.dev/packages/shared_preferences) (offline-first JSON persistence)
- **Typography & Icons:** [`google_fonts`](https://pub.dev/packages/google_fonts), [`cupertino_icons`](https://pub.dev/packages/cupertino_icons)

---

## Getting Started (For Developers)

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and added to your `PATH`
  > **Windows Tip:** Install the Flutter SDK in a folder **without spaces** (for example, `C:\flutter`) to avoid build hook errors on Windows.
- Android Studio / VS Code with Flutter & Dart plugins
- A connected physical device (with USB Debugging enabled) or an Android/iOS emulator

### Installation & Running Locally

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Kemeno01/Sakto.git
   cd Sakto
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Check connected devices:**
   ```bash
   flutter devices
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

### Building an Android Debug APK
```bash
flutter build apk --debug
```
The generated APK will be located at `build/app/outputs/flutter-apk/app-debug.apk`.

---

## Project Structure

```text
Sakto/
├── lib/
│   └── main.dart          # Complete app: models, AppState, Home, Lists, Split, Analytics & UI sheets
├── android/               # Android platform configuration
├── ios/                   # iOS platform configuration
├── web/                   # Web platform configuration
├── windows/               # Windows desktop configuration
├── macos/                 # macOS desktop configuration
├── linux/                 # Linux desktop configuration
├── test/                  # Widget/unit tests
├── pubspec.yaml           # Project metadata & dependencies
└── README.md              # Project documentation
```

---

## Troubleshooting

- **`'C:\Users\...' is not recognized as an internal or external command` (Windows):**
  Move your Flutter SDK to a path without spaces (e.g., `C:\flutter`), update your Windows `PATH`, update `android/local.properties`, and run `flutter clean && flutter pub get`.
- **`No pubspec.yaml file found`:**
  Make sure your terminal is inside the `Sakto` root folder (`cd Sakto`) before running Flutter commands.
- **No devices found:**
  Enable **Developer Options → USB Debugging** on your Android phone (or launch an emulator), then run `flutter devices`.

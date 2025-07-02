# GoCart — Flutter App with Build Flavors

This project uses **Flutter build flavors** to generate and run three separate versions of the app:

- **Instance A**
- **Instance B**
- **Instance C**

Each version has its own entrypoint and configuration.

---

## 🚀 Running the App (Flavors)

### Instance A
```bash
flutter run --flavor instanceA -t lib/main_a.dart
````

### Instance B

```bash
flutter run --flavor instanceB -t lib/main_b.dart
```

### Instance C

```bash
flutter run --flavor instanceC -t lib/main_c.dart
```

---

## 🛠 Building APKs (Per Flavor)

### Instance A

```bash
flutter build apk --flavor instanceA -t lib/main_a.dart -o build/instanceA
```

### Instance B

```bash
flutter build apk --flavor instanceB -t lib/main_b.dart -o build/instanceB
```

### Instance C

```bash
flutter build apk --flavor instanceC -t lib/main_c.dart -o build/instanceC
```

---

## VS Code Setup (Optional)

To run flavors easily in VS Code, use the predefined launch configurations in `.vscode/launch.json`.

Example launch configuration:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Instance A",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_a.dart",
      "args": ["--flavor", "instanceA"]
    },
    {
      "name": "Instance B",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_b.dart",
      "args": ["--flavor", "instanceB"]
    },
    {
      "name": "Instance C",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_c.dart",
      "args": ["--flavor", "instanceC"]
    }
  ]
}
```

To use:

1. Open the **Run and Debug** panel in VS Code.
2. Select the desired configuration (e.g., "Instance A").
3. Click ▶️ to launch.

---

## Requirements

* Flutter 3.7.3 (or compatible)
* Dart SDK 3.7+
* Android Studio or VS Code with Flutter plugin
* Android SDK (for building APKs)

---

## Flavor Entry Files

* `lib/main_a.dart`
* `lib/main_b.dart`
* `lib/main_c.dart`

Each entry file initializes an `AppConfig` and passes it to `MyApp` in `lib/app.dart`.

The shared app logic and UI lives in `lib/app.dart`, which builds the app according to the provided flavor configuration.



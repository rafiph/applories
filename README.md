# applories

A Flutter calorie tracking app that uses Gemini Vision to analyze food images.

## Prerequisites

- Flutter SDK
- Firebase project
- Gemini API key from [aistudio.google.com](https://aistudio.google.com)

## Setup

### 1. Firebase configuration

**`lib/firebase_options.dart`**
**`android/google-services.json`** 

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Gemini API key

Get a key from [aistudio.google.com](https://aistudio.google.com) → **Get API key**.

### 4. Run the app
```bash
flutter run --dart-define=GEMINI_API_KEY=your_gemini_api_key_here
```
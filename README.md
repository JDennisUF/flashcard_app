# Flashcard App

A beautiful, cross-platform Flutter app for studying with flashcards. Supports desktop, mobile, and web!

---

## ✨ Features

- **Animated Flashcards:** Tap or click to flip between question and answer.
- **Multiple Sets:** Organize cards into named sets. Add, delete, and switch sets easily.
- **Import from CSV:** Quickly import flashcards from CSV files (works on desktop and web).
- **Random Order:** Shuffle cards for randomized study sessions.
- **Progress Tracking:** See which card you're on (e.g., "Card 3 of 10").
- **Previous/Next Navigation:** Move forward and backward through cards.
- **Desktop Window Sizing:** Compact, modern UI for desktop.
- **Persistent Storage:** All sets and cards are saved using Hive.
- **Customizable:** Easily add your own sets, cards, and app icon.

---

## 🚀 Getting Started

1. **Install Flutter:** [Flutter Install Guide](https://docs.flutter.dev/get-started/install)
2. **Clone this repo:**
   ```bash
   git clone <your-repo-url>
   cd flashcard_app
   ```
3. **Set up environment variables:**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` and add your Supabase credentials:
   ```
   SUPABASE_URL=your_supabase_url_here
   SUPABASE_ANON_KEY=your_supabase_anon_key_here
   ```
4. **Install dependencies:**
   ```bash
   flutter pub get
   ```
5. **Run the app:**
   - **Desktop:** `flutter run -d windows` (or `linux`, `macos`)
   - **Web:** `flutter run -d chrome` (for debug) or build for release (see below)
   - **Mobile:** `flutter run -d <device>`

---

## 🌐 Deploying as a Web App

1. Build for web:
   ```bash
   flutter build web --release
   ```
2. Host the contents of `build/web` on GitHub Pages, Netlify, Firebase Hosting, or any static web server.
3. Share your app link!

---

## 📦 Importing Flashcards from CSV
- Click the **Import** button and select a CSV file.
- Format: Each row should have a question and answer (quoted or unquoted).
- Example:
  ```csv
  "What is the capital of France?","Paris"
  "What is 2 + 2?",4
  ```

---

## 🖼️ Custom App Icon
- Replace the default icon files in the platform folders (see Flutter docs for details).

---

## 📝 Credits & Resources
- Built with [Flutter](https://flutter.dev/)
- Uses [Hive](https://docs.hivedb.dev/), [file_picker](https://pub.dev/packages/file_picker), [csv](https://pub.dev/packages/csv), and more.

---

## 📚 More Info
- [Flutter Documentation](https://docs.flutter.dev/)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

---

Enjoy studying with your new flashcard app!

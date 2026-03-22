# Project Insight: KONEK Social Media

This document provides a detailed breakdown of the **KONEK Social Media** Flutter project, explaining the purpose and content of each directory and key file.

---

## 📂 Project Structure Overview

### 1. `lib/` (The Core)
This is where all the Dart code for the application resides.

#### `lib/main.dart`
- **Purpose**: The entry point of the application.
- **Function**: Initializes the Flutter app and **Firebase**, sets up the global theme, and sets the `LoginScreen` as the starting page.

---

### 2. `lib/services/`
Contains service classes for external integrations.

#### `auth_service.dart`
- **Purpose**: Centralized authentication logic using **Firebase Auth**.
- **Features**: 
    - Email/Password Sign-In & Sign-Up
    - **Google Sign-In**: Provides a convenient one-tap login experience using Google accounts.
    - Password Reset via email.
    - Global Sign-Out.

---

### 3. `lib/screens/`
Contains the full-page UI components (Screens).

- **`login_screen.dart`**: Polished login page with Email/Password and Google Sign-In options.
- **`sign_up_screen.dart`**: New screen for creating accounts via Firebase.
- **`forgot_password_screen.dart`**: Recovery screen to send password reset emails.
- **`main_screen.dart`**: Post-login "shell" with a `BottomNavigationBar`.
- **`home_page.dart`**: Main post feed.
- **`reels_page.dart`**: TikTok-style vertical video feed.
- **`chat_page.dart`**: Messaging system with chat list and chat rooms.
- **`profile_screen.dart`**: User profile with tabs for content.
- **`settings_screen.dart`**: Allows users to manage notifications, dark mode, and account privacy. Displays static account info and provides a unified **Edit Profile** modal.

---

### 4. `lib/widgets/`
Reusable UI components.

- **`app_drawer.dart`**: Refined navigation menu with a custom header (Avatar on left, Username/Button on right). Email addresses are hidden for privacy.
- **`post_widget.dart`**: Dynamic content renderer.
- **`stories_bar.dart`**: Horizontal story list.

---

## 🔐 Authentication & Backend
The app uses **Firebase** for its backend infrastructure:
- **Firebase Auth**: Manages user identities and security.
- **Google Sign-In**: This works by using the `google_sign_in` package to retrieve an authentication token from Google, which is then passed to Firebase to create or log into a project-linked account.
- **Password Recovery**: Automated reset emails are handled directly by Firebase services.

---

## 💡 Key Technical Insights
1. **Unified Editing**: The **Edit Profile** modal is consistent across the app.
2. **Data Privacy**: Sensitive info like emails are removed from headers.
3. **Scalability**: The `AuthService` makes it easy to add more providers or change auth logic.

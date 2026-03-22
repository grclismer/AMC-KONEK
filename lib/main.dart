import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/post_service.dart';

/// The entry point of the Flutter application. 
/// It initializes Firebase and sets up the app environment.
void main() async {
  // Ensures that Flutter widget binding is initialized before Firebase initialization.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initializes Firebase using the default options for the current platform.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Background cleanup of expired posts
  PostService.instance.cleanupExpiredPosts();

  // Runs the root widget of the application.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KONEK Social Media',
      themeMode: ThemeMode.dark,
      theme: AppTheme.darkTheme(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          if (snapshot.hasData && snapshot.data != null) {
            return const MainScreen();
          }
          
          return const LoginScreen();
        },
      ),
    );
  }
}

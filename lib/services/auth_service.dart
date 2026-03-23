import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fix: If you are testing on Web, you may need to pass clientId: 'YOUR_CLIENT_ID' here
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint("Login Error: $e");
      rethrow;
    }
  }
  // Add these methods inside your AuthService class in lib/services/auth_service.dart

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

// Helper for the Menu Screen
  Stream<DocumentSnapshot> getUserDataStream() {
    final uid = _auth.currentUser?.uid ?? '';
    return _firestore.collection('users').doc(uid).snapshots();
  }

  Future<void> saveUserData(Map<String, dynamic> data) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      // Merge true ensures we don't overwrite the whole document
      await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
    }
  }

  Future<UserCredential?> signUpWithEmail(String email, String password, String displayName) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (credential.user != null) {
        final username = displayName
            .toLowerCase()
            .trim()
            .replaceAll(' ', '.')
            .replaceAll(RegExp(r'[^a-z0-9.]'), '');

        await credential.user!.updateDisplayName(displayName);
        await credential.user!.reload();

        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email,
          'username': username,
          'displayName': displayName,
          'usernameLower': username.toLowerCase(),
          'displayNameLower': displayName.toLowerCase(),
          'photoURL': 'https://randomuser.me/api/portraits/lego/1.jpg',
          'createdAt': FieldValue.serverTimestamp(),
          'bio': '',
          'friends': [],
          'pendingRequests': [],
          'sentRequests': [],
          'following': [],
          'followers': [],
          'friendCount': 0,
          'followingCount': 0,
          'followersCount': 0,
          'postCount': 0,
          'searchCount': 0,
        });
      }
      return credential;
    } catch (e) {
      debugPrint("Sign Up Error: $e");
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();

        if (!userDoc.exists) {
          final displayName = userCredential.user!.displayName ?? 'User';
          final username = displayName
              .toLowerCase()
              .trim()
              .replaceAll(' ', '.')
              .replaceAll(RegExp(r'[^a-z0-9.]'), '');

          await _firestore.collection('users').doc(userCredential.user!.uid).set({
            'uid': userCredential.user!.uid,
            'email': userCredential.user!.email ?? '',
            'displayName': displayName,
            'username': username,
            'usernameLower': username.toLowerCase(),
            'displayNameLower': displayName.toLowerCase(),
            'photoURL': userCredential.user!.photoURL ?? 'https://randomuser.me/api/portraits/lego/1.jpg',
            'bio': '',
            'createdAt': FieldValue.serverTimestamp(),
            'friends': [],
            'following': [],
            'followers': [],
            'pendingRequests': [],
            'sentRequests': [],
            'friendCount': 0,
            'followersCount': 0,
            'followingCount': 0,
            'postCount': 0,
            'searchCount': 0,
          });
        }
      }
      return userCredential;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      rethrow;
    }
  }

  // Rest of your methods (migrateUsernames, updateProfile, followUser, etc.) remain the same...

  Future<void> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint("Error signing out from Google: $e");
    }
    await _auth.signOut();
  }
}
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns the currently authenticated Firebase user, or null if no user is signed in.
  User? get currentUser => _auth.currentUser;

  /// Signs in a user using their email and password.
  /// Returns a [UserCredential] on success, or throws an error on failure.
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint("Login Error: $e");
      rethrow;
    }
  }

  /// Creates a new user account with the provided email, password, and username.
  /// Returns a [UserCredential] for the newly created user.
  Future<UserCredential?> signUpWithEmail(String email, String password, String displayName) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (credential.user != null) {
        // Generate username from display name
        final username = displayName
          .toLowerCase()
          .trim()
          .replaceAll(' ', '.')
          .replaceAll(RegExp(r'[^a-z0-9.]'), '');

        // Update Firebase Auth profile
        await credential.user!.updateDisplayName(displayName);
        await credential.user!.reload();
        
        // Initialize user document in Firestore - Phase 1 Kakonek
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email,
          'username': username,
          'displayName': displayName,
          'usernameLower': username.toLowerCase(),
          'displayNameLower': displayName.toLowerCase(),
          'photoURL': 'https://randomuser.me/api/portraits/lego/1.jpg', // Default avatar
          'createdAt': FieldValue.serverTimestamp(),
          'bio': '',
          'friends': [],
          'pendingRequests': [],
          'sentRequests': [],
          'friendCount': 0,
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

  /// Initiates the Google Sign-In flow and authenticates with Firebase.
  /// Returns a [UserCredential] if successful, or null if the user cancels the process.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

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
            'photoURL': userCredential.user!.photoURL ?? '',
            'bio': '',
            'createdAt': FieldValue.serverTimestamp(),
            'friends': [],
            'pendingRequests': [],
            'sentRequests': [],
            'friendCount': 0,
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

  /// One-time migration to add usernames to existing users
  Future<void> migrateUsernames() async {
    print('Starting username migration...');
    final snapshot = await _firestore.collection('users').get();
    
    int updated = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      
      // Skip if already has username
      if (data['username'] != null && data['username'].toString().isNotEmpty) {
        continue;
      }
      
      // Generate username from displayName or email
      String username = '';
      if (data['displayName'] != null && data['displayName'].toString().isNotEmpty) {
        username = data['displayName']
          .toString()
          .toLowerCase()
          .trim()
          .replaceAll(' ', '.')
          .replaceAll(RegExp(r'[^a-z0-9.]'), '');
      } else if (data['email'] != null) {
        username = data['email'].toString().split('@').first.toLowerCase();
      } else {
        username = 'user${doc.id.substring(0, 8)}';
      }
      
      // Ensure uniqueness
      final existing = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .get();
      
      if (existing.docs.isNotEmpty && existing.docs.first.id != doc.id) {
        username = '${username}${DateTime.now().millisecondsSinceEpoch % 1000}';
      }
      
      await doc.reference.update({
        'username': username,
        'usernameLower': username.toLowerCase(),
      });
      updated++;
    }
    print('Migration complete! Updated $updated users.');
  }

  /// Updates the user's display name and photo URL in Firebase Auth and Firestore.
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        if (displayName != null) await user.updateDisplayName(displayName);
        if (photoURL != null) await user.updatePhotoURL(photoURL);
        
        // Sync with Firestore
        await saveUserData({
          if (displayName != null) 'displayName': displayName,
          if (displayName != null) 'displayNameLower': displayName.toLowerCase(),
          if (photoURL != null) 'photoURL': photoURL,
        });
      }
    } catch (e) {
      debugPrint("Update Profile Error: $e");
      rethrow;
    }
  }

  /// Saves or updates user data in the Firestore 'users' collection.
  Future<void> saveUserData(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user != null) {
      final Map<String, dynamic> updatedData = Map.from(data);
      
      // Auto-add lowercase fields for search indexing
      if (data.containsKey('username')) {
        updatedData['usernameLower'] = data['username'].toString().toLowerCase();
      }
      if (data.containsKey('displayName')) {
        updatedData['displayNameLower'] = data['displayName'].toString().toLowerCase();
      }

      await _firestore.collection('users').doc(user.uid).set(
        updatedData,
        SetOptions(merge: true),
      );
    }
  }

  /// Returns a stream of any user's data from Firestore.
  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// Returns a stream of the current user's data from Firestore.
  Stream<DocumentSnapshot> getUserDataStream() {
    final user = _auth.currentUser;
    if (user != null) {
      return getUserStream(user.uid);
    }
    return const Stream.empty();
  }

  /// Follows a user by updating both users' Firestore documents.
  Future<void> followUser(String targetUid) async {
    final user = _auth.currentUser;
    if (user != null && user.uid != targetUid) {
      final batch = _firestore.batch();
      
      // Update current user's following list and count
      batch.update(_firestore.collection('users').doc(user.uid), {
        'following': FieldValue.arrayUnion([targetUid]),
        'followingCount': FieldValue.increment(1),
      });
      
      // Update target user's followers count
      batch.update(_firestore.collection('users').doc(targetUid), {
        'followersCount': FieldValue.increment(1),
      });
      
      await batch.commit();
    }
  }

  /// Unfollows a user by updating both users' Firestore documents.
  Future<void> unfollowUser(String targetUid) async {
    final user = _auth.currentUser;
    if (user != null && user.uid != targetUid) {
      final batch = _firestore.batch();
      
      // Update current user's following list and count
      batch.update(_firestore.collection('users').doc(user.uid), {
        'following': FieldValue.arrayRemove([targetUid]),
        'followingCount': FieldValue.increment(-1),
      });
      
      // Update target user's followers count
      batch.update(_firestore.collection('users').doc(targetUid), {
        'followersCount': FieldValue.increment(-1),
      });
      
      await batch.commit();
    }
  }

  /// Updates the user's password in Firebase Auth.
  Future<void> changePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
      }
    } catch (e) {
      debugPrint("Change Password Error: $e");
      rethrow;
    }
  }

  /// Sends a password reset email to the specified email address.
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint("Reset Error: $e");
      rethrow;
    }
  }

  /// Returns the username from Firestore for the given UID.
  Future<String> getUsername(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['username'] ?? 'User';
      }
      return 'User';
    } catch (e) {
      debugPrint("Get Username Error: $e");
      return 'User';
    }
  }

  /// Signs out the current user from both Firebase and Google Sign-In.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint("Error signing out from Google: $e");
    }
    await _auth.signOut();
  }
}

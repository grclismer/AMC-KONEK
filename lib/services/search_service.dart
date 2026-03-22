import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/search_history.dart';

class SearchService {
  static final SearchService instance = SearchService._internal();
  factory SearchService() => instance;
  SearchService._internal();
  
  final _firestore = FirebaseFirestore.instance;
  
  // Track search
  Future<void> trackSearch(String searchedUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    // Don't track searching yourself
    if (currentUser.uid == searchedUserId) return;

    final history = SearchHistory(
      userId: currentUser.uid,
      searchedUserId: searchedUserId,
      timestamp: DateTime.now(),
    );
    
    await _firestore.collection('search_history').add(history.toFirestore());
    
    // Update search count on searched user
    await _firestore.collection('users').doc(searchedUserId).update({
      'searchCount': FieldValue.increment(1),
    });
  }
  
  // Search users by username or display name (Robust Case-Insensitive)
  Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    
    // Clean query - remove @ if present, make lowercase
    String cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.startsWith('@')) {
      cleanQuery = cleanQuery.substring(1);
    }
    
    try {
      // Get all users (for small databases)
      final snapshot = await _firestore
        .collection('users')
        .get();
      
      final allUsers = snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .toList();
      
      // Filter by username OR displayName (client-side for max accuracy)
      final results = allUsers.where((user) {
        if (user.uid == currentUser.uid) return false;
        
        final username = user.username.toLowerCase();
        final displayName = user.displayName.toLowerCase();
        
        return username.contains(cleanQuery) ||
               displayName.contains(cleanQuery);
      }).toList();
      
      // Sort by relevance (exact matches first)
      results.sort((a, b) {
        final aUsername = a.username.toLowerCase();
        final bUsername = b.username.toLowerCase();
        final aName = a.displayName.toLowerCase();
        final bName = b.displayName.toLowerCase();
        
        // Exact username match comes first
        if (aUsername == cleanQuery) return -1;
        if (bUsername == cleanQuery) return 1;
        
        // Username starts with query
        if (aUsername.startsWith(cleanQuery) && !bUsername.startsWith(cleanQuery)) return -1;
        if (bUsername.startsWith(cleanQuery) && !aUsername.startsWith(cleanQuery)) return 1;
        
        // Display name starts with query
        if (aName.startsWith(cleanQuery) && !bName.startsWith(cleanQuery)) return -1;
        if (bName.startsWith(cleanQuery) && !aName.startsWith(cleanQuery)) return 1;
        
        return b.friendCount.compareTo(a.friendCount);
      });
      
      return results.take(30).toList();
    } catch (e) {
      print('Search error: $e');
      return [];
    }
  }

  // Optimized search for large databases using lowercase indexed fields
  Future<List<UserModel>> searchUsersOptimized(String query) async {
    if (query.isEmpty) return [];
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    
    // Clean query
    String cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.startsWith('@')) {
      cleanQuery = cleanQuery.substring(1);
    }
    
    final results = <UserModel>[];
    final seenIds = <String>{};
    
    try {
      // Search by usernameLower (Firestore query)
      final usernameLowerQuery = await _firestore
        .collection('users')
        .where('usernameLower', isGreaterThanOrEqualTo: cleanQuery)
        .where('usernameLower', isLessThan: '${cleanQuery}z')
        .limit(20)
        .get();
      
      for (var doc in usernameLowerQuery.docs) {
        final user = UserModel.fromFirestore(doc);
        if (user.uid != currentUser.uid && !seenIds.contains(user.uid)) {
          results.add(user);
          seenIds.add(user.uid);
        }
      }
      
      // Search by displayNameLower (Firestore query)
      final nameLowerQuery = await _firestore
        .collection('users')
        .where('displayNameLower', isGreaterThanOrEqualTo: cleanQuery)
        .where('displayNameLower', isLessThan: '${cleanQuery}z')
        .limit(20)
        .get();
      
      for (var doc in nameLowerQuery.docs) {
        final user = UserModel.fromFirestore(doc);
        if (user.uid != currentUser.uid && !seenIds.contains(user.uid)) {
          results.add(user);
          seenIds.add(user.uid);
        }
      }
      
      return results;
    } catch (e) {
      print('Search error: $e');
      // Fallback to simple search
      return searchUsers(query);
    }
  }
  
  // Get intelligent recommendations
  Future<List<UserModel>> getRecommendations() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    
    // Get current user data
    final userDoc = await _firestore
      .collection('users')
      .doc(currentUser.uid)
      .get();
    final userData = userDoc.data() ?? {};
    final friends = List<String>.from(userData['friends'] ?? []);
    final pending = List<String>.from(userData['pendingRequests'] ?? []);
    final sent = List<String>.from(userData['sentRequests'] ?? []);
    
    // Get sample users (Handle empty databases or missing searchCount)
    final snapshot = await _firestore
      .collection('users')
      .limit(100)
      .get();
    
    var recommendations = snapshot.docs
      .map((doc) => UserModel.fromFirestore(doc))
      .where((user) =>
        user.uid != currentUser.uid &&
        !friends.contains(user.uid) &&
        !pending.contains(user.uid) &&
        !sent.contains(user.uid))
      .toList();
    
    // Sort by composite score (Mutual Friends > Overall Popularity)
    recommendations.sort((a, b) {
      final scoreA = _calculateScore(a, friends);
      final scoreB = _calculateScore(b, friends);
      return scoreB.compareTo(scoreA);
    });
    
    return recommendations.take(20).toList();
  }
  
  int _calculateScore(UserModel user, List<String> myFriends) {
    int score = 0;
    
    // Points for mutual friends (Highest weight)
    final mutualCount = user.friends
      .where((friendId) => myFriends.contains(friendId))
      .length;
    score += mutualCount * 20; // 20 points per mutual friend
    
    // Points for overall friend count (Social proof)
    score += user.friendCount;
    
    // Points for being searched (Popularity/Trending)
    score += user.searchCount * 2;
    
    return score;
  }
  
  // Get user's recent searches
  Future<List<UserModel>> getRecentSearches() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    
    final snapshot = await _firestore
      .collection('search_history')
      .where('userId', isEqualTo: currentUser.uid)
      .orderBy('timestamp', descending: true)
      .limit(20) // Get more to account for duplicates from multiple searches of same user
      .get();
    
    final searchedUserIds = snapshot.docs
      .map((doc) => doc.data()['searchedUserId'] as String)
      .toSet() // Deduplicate
      .toList()
      .take(10) // Limit to 10 unique recent searches
      .toList();
    
    if (searchedUserIds.isEmpty) return [];
    
    // Get user details
    final users = <UserModel>[];
    for (var i = 0; i < searchedUserIds.length; i += 10) {
      final batch = searchedUserIds.sublist(
        i,
        i + 10 > searchedUserIds.length ? searchedUserIds.length : i + 10,
      );
      
      final userSnapshot = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: batch)
        .get();
      
      users.addAll(
        userSnapshot.docs.map((doc) => UserModel.fromFirestore(doc)),
      );
    }
    
    // Maintain order from searchedUserIds (recent first)
    final orderedUsers = <UserModel>[];
    for (var id in searchedUserIds) {
      final user = users.where((u) => u.uid == id).firstOrNull;
      if (user != null) orderedUsers.add(user);
    }
    
    return orderedUsers;
  }
}

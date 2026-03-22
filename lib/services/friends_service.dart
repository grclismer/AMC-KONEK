import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class FriendsService {
  static final FriendsService instance = FriendsService._internal();
  factory FriendsService() => instance;
  FriendsService._internal();
  
  final _firestore = FirebaseFirestore.instance;
  
  // Send friend request
  Future<void> sendFriendRequest(String toUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not logged in');
    
    // Get current user data
    final userDoc = await _firestore
      .collection('users')
      .doc(currentUser.uid)
      .get();
    final userData = userDoc.data() ?? {};
    
    // Create friend request
    final request = FriendRequest(
      id: '',
      fromUserId: currentUser.uid,
      fromUsername: userData['username'] ?? '',
      fromDisplayName: userData['displayName'] ?? '',
      fromPhotoURL: userData['photoURL'] ?? '',
      toUserId: toUserId,
      timestamp: DateTime.now(),
      status: FriendRequestStatus.pending,
    );
    
    // Use transaction for atomic operation
    await _firestore.runTransaction((transaction) async {
      // Add request document
      final requestRef = _firestore.collection('friend_requests').doc();
      transaction.set(requestRef, request.toFirestore());
      
      // Update sender's sentRequests
      final senderRef = _firestore.collection('users').doc(currentUser.uid);
      transaction.update(senderRef, {
        'sentRequests': FieldValue.arrayUnion([toUserId]),
      });
      
      // Update receiver's pendingRequests
      final receiverRef = _firestore.collection('users').doc(toUserId);
      transaction.update(receiverRef, {
        'pendingRequests': FieldValue.arrayUnion([currentUser.uid]),
      });
    });
  }
  
  // Accept friend request
  Future<void> acceptFriendRequest(String requestId, String fromUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not logged in');
    
    await _firestore.runTransaction((transaction) async {
      // Update request status
      final requestRef = _firestore.collection('friend_requests').doc(requestId);
      transaction.update(requestRef, {
        'status': FriendRequestStatus.accepted.toString().split('.').last,
      });
      
      // Add to friends lists (both users)
      final user1Ref = _firestore.collection('users').doc(currentUser.uid);
      transaction.update(user1Ref, {
        'friends': FieldValue.arrayUnion([fromUserId]),
        'pendingRequests': FieldValue.arrayRemove([fromUserId]),
        'friendCount': FieldValue.increment(1),
      });
      
      final user2Ref = _firestore.collection('users').doc(fromUserId);
      transaction.update(user2Ref, {
        'friends': FieldValue.arrayUnion([currentUser.uid]),
        'sentRequests': FieldValue.arrayRemove([currentUser.uid]),
        'friendCount': FieldValue.increment(1),
      });
    });
  }
  
  // Reject friend request
  Future<void> rejectFriendRequest(String requestId, String fromUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not logged in');
    
    await _firestore.runTransaction((transaction) async {
      // Update request status
      final requestRef = _firestore.collection('friend_requests').doc(requestId);
      transaction.update(requestRef, {
        'status': FriendRequestStatus.rejected.toString().split('.').last,
      });
      
      // Remove from pending/sent lists
      final receiverRef = _firestore.collection('users').doc(currentUser.uid);
      transaction.update(receiverRef, {
        'pendingRequests': FieldValue.arrayRemove([fromUserId]),
      });
      
      final senderRef = _firestore.collection('users').doc(fromUserId);
      transaction.update(senderRef, {
        'sentRequests': FieldValue.arrayRemove([currentUser.uid]),
      });
    });
  }
  
  // Remove friend (unfriend)
  Future<void> removeFriend(String friendUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not logged in');
    
    await _firestore.runTransaction((transaction) async {
      final user1Ref = _firestore.collection('users').doc(currentUser.uid);
      transaction.update(user1Ref, {
        'friends': FieldValue.arrayRemove([friendUserId]),
        'friendCount': FieldValue.increment(-1),
      });
      
      final user2Ref = _firestore.collection('users').doc(friendUserId);
      transaction.update(user2Ref, {
        'friends': FieldValue.arrayRemove([currentUser.uid]),
        'friendCount': FieldValue.increment(-1),
      });
    });
  }
  
  // Get pending requests stream
  Stream<List<FriendRequest>> getPendingRequestsStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.fromIterable([[]]);
    
    // Removing orderBy to ensure it works even without composite indexes
    return _firestore
      .collection('friend_requests')
      .where('toUserId', isEqualTo: currentUser.uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) {
        final requests = snapshot.docs
          .map((doc) => FriendRequest.fromFirestore(doc))
          .toList();
        
        // Sort client-side to be safe
        requests.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return requests;
      });
  }
  
  // Get friends stream (Broadcast compliant)
  Stream<List<UserModel>> getFriendsStream(String userId) async* {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data();
    final friendIds = List<String>.from(userData?['friends'] ?? []);
    
    if (friendIds.isEmpty) {
      yield [];
      return;
    }
    
    // Firestore 'whereIn' limit is 10
    if (friendIds.length <= 10) {
      yield* _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: friendIds)
        .snapshots()
        .map((snapshot) => snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList());
    } else {
      // For >10 friends, use a stream controller to manage multiple batches
      final controller = StreamController<List<UserModel>>.broadcast();
      final batches = <List<String>>[];
      for (var i = 0; i < friendIds.length; i += 10) {
        batches.add(friendIds.sublist(i, i + 10 > friendIds.length ? friendIds.length : i + 10));
      }

      final allFriendsByBatch = <int, List<UserModel>>{};
      final subscriptions = <StreamSubscription>[];

      for (int i = 0; i < batches.length; i++) {
        final sub = _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batches[i])
          .snapshots()
          .listen((snapshot) {
            allFriendsByBatch[i] = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
            
            // Reconstruct full list
            final fullList = <UserModel>[];
            for (var j = 0; j < batches.length; j++) {
              if (allFriendsByBatch.containsKey(j)) {
                fullList.addAll(allFriendsByBatch[j]!);
              }
            }
            if (!controller.isClosed) controller.add(fullList);
          });
        subscriptions.add(sub);
      }

      controller.onCancel = () {
        for (var sub in subscriptions) {
          sub.cancel();
        }
        controller.close();
      };

      yield* controller.stream;
    }
  }

  
  // Get friend recommendations
  Future<List<UserModel>> getFriendRecommendations() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    
    final userDoc = await _firestore
      .collection('users')
      .doc(currentUser.uid)
      .get();
    final userData = userDoc.data();
    final friends = List<String>.from(userData?['friends'] ?? []);
    final pending = List<String>.from(userData?['pendingRequests'] ?? []);
    final sent = List<String>.from(userData?['sentRequests'] ?? []);
    
    // Get random users (excluding self, friends, and pending)
    final snapshot = await _firestore
      .collection('users')
      .limit(20)
      .get();
    
    final recommendations = snapshot.docs
      .map((doc) => UserModel.fromFirestore(doc))
      .where((user) =>
        user.uid != currentUser.uid &&
        !friends.contains(user.uid) &&
        !pending.contains(user.uid) &&
        !sent.contains(user.uid))
      .take(10)
      .toList();
    
    return recommendations;
  }
  
  // Check if users are friends
  Future<bool> areFriends(String userId1, String userId2) async {
    final userDoc = await _firestore.collection('users').doc(userId1).get();
    final friends = List<String>.from(userDoc.data()?['friends'] ?? []);
    return friends.contains(userId2);
  }
  
  // Get friendship status
  Future<FriendshipStatus> getFriendshipStatus(
    String currentUserId,
    String otherUserId,
  ) async {
    final userDoc = await _firestore
      .collection('users')
      .doc(currentUserId)
      .get();
    final userData = userDoc.data() ?? {};
    
    final friends = List<String>.from(userData['friends'] ?? []);
    final pending = List<String>.from(userData['pendingRequests'] ?? []);
    final sent = List<String>.from(userData['sentRequests'] ?? []);
    
    if (friends.contains(otherUserId)) {
      return FriendshipStatus.friends;
    } else if (sent.contains(otherUserId)) {
      return FriendshipStatus.requestSent;
    } else if (pending.contains(otherUserId)) {
      return FriendshipStatus.requestReceived;
    } else {
      return FriendshipStatus.notFriends;
    }
  }

  /// Returns the count of mutual friends between the current user and [otherUid].
  Future<int> getMutualFriendsCount(String otherUid) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return 0;

    try {
      final results = await Future.wait([
        _firestore.collection('users').doc(myUid).get(),
        _firestore.collection('users').doc(otherUid).get(),
      ]);

      final myFriends = List<String>.from(results[0].data()?['friends'] ?? []);
      final theirFriends = List<String>.from(results[1].data()?['friends'] ?? []);

      final intersection = myFriends.where((friend) => theirFriends.contains(friend));
      return intersection.length;
    } catch (e) {
      return 0;
    }
  }

  // Helper method for real-time friend check
  Stream<bool> isFriendStream(String otherUserId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.fromIterable([false]);

    return _firestore.collection('users').doc(currentUser.uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return false;
      final friends = List<String>.from(snapshot.data()?['friends'] ?? []);
      return friends.contains(otherUserId);
    }).asBroadcastStream();
  }
}

enum FriendshipStatus {
  friends,
  requestSent,
  requestReceived,
  notFriends,
}

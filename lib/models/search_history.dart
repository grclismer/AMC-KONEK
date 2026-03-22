import 'package:cloud_firestore/cloud_firestore.dart';

class SearchHistory {
  final String userId;
  final String searchedUserId;
  final DateTime timestamp;
  
  SearchHistory({
    required this.userId,
    required this.searchedUserId,
    required this.timestamp,
  });
  
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'searchedUserId': searchedUserId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

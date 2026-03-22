import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class UserPhotoWidget extends StatelessWidget {
  final String userId;
  final double radius;
  final bool showBorder;
  final Gradient? borderGradient;
  final Color? borderColor;
  final double borderWidth;
  
  const UserPhotoWidget({
    super.key,
    required this.userId,
    this.radius = 20,
    this.showBorder = false,
    this.borderGradient,
    this.borderColor,
    this.borderWidth = 2,
  });
  
  ImageProvider? _getProfileImage(String? url) {
    if (url == null || url.isEmpty) return null;
    
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (e) {
        return null;
      }
    }
    
    if (url.startsWith('http')) {
      return NetworkImage(url);
    }
    
    return null;
  }
  
  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[800],
        child: Icon(Icons.person, size: radius, color: Colors.grey),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final photoURL = userData['photoURL'];
        
        Widget avatar = CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[800],
          backgroundImage: _getProfileImage(photoURL),
          child: _getProfileImage(photoURL) == null
            ? Icon(Icons.person, size: radius, color: Colors.grey)
            : null,
        );
        
        if (showBorder) {
          return Container(
            padding: EdgeInsets.all(borderWidth),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: borderGradient,
              border: (borderColor != null && borderGradient == null)
                ? Border.all(color: borderColor!, width: borderWidth)
                : null,
            ),
            child: avatar,
          );
        }
        
        return avatar;
      },
    );
  }
}

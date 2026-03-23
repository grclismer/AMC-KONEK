import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class UserPhotoWidget extends StatefulWidget {
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

  @override
  State<UserPhotoWidget> createState() => _UserPhotoWidgetState();
}

class _UserPhotoWidgetState extends State<UserPhotoWidget> {
  // Cache the last known good image provider — never go back to null once loaded
  ImageProvider? _cachedImage;
  String? _lastUrl;

  ImageProvider? _getProfileImage(String? url) {
    if (url == null || url.isEmpty) return null;

    // Return cached if URL hasn't changed
    if (url == _lastUrl && _cachedImage != null) return _cachedImage;

    ImageProvider? provider;
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        provider = MemoryImage(base64Decode(base64String));
      } catch (_) {
        return _cachedImage; // keep old image on decode error
      }
    } else if (url.startsWith('http')) {
      provider = NetworkImage(url);
    }

    if (provider != null) {
      _lastUrl = url;
      _cachedImage = provider;
    }

    return _cachedImage;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) {
      return _buildAvatar(null);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        // While waiting, show cached image if we have one — don't flash the icon
        if (snapshot.connectionState == ConnectionState.waiting && _cachedImage != null) {
          return _buildAvatar(_cachedImage);
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final photoURL = userData['photoURL'] as String?;
        final image = _getProfileImage(photoURL);

        return _buildAvatar(image);
      },
    );
  }

  Widget _buildAvatar(ImageProvider? image) {
    final avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor: Colors.grey[800],
      backgroundImage: image,
      child: image == null
          ? Icon(Icons.person, size: widget.radius, color: Colors.grey)
          : null,
    );

    if (widget.showBorder) {
      return Container(
        padding: EdgeInsets.all(widget.borderWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: widget.borderGradient,
          border: (widget.borderColor != null && widget.borderGradient == null)
              ? Border.all(color: widget.borderColor!, width: widget.borderWidth)
              : null,
        ),
        child: avatar,
      );
    }

    return avatar;
  }
}
import 'package:flutter/material.dart';
import 'dart:ui';
import 'app_theme.dart';

class GradientUtils {
  /// Defines the primary app gradient (Purple to Pink).
  ///
  /// Example:
  /// ```dart
  /// Container(decoration: BoxDecoration(gradient: GradientUtils.primaryGradient))
  /// ```
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [AppTheme.primaryPurple, AppTheme.primaryPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Defines the secondary app gradient (Custom Blue gradient).
  ///
  /// Example:
  /// ```dart
  /// Container(decoration: BoxDecoration(gradient: GradientUtils.secondaryGradient))
  /// ```
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Helper rendering gradient text effects using ShaderMask.
  ///
  /// Example:
  /// ```dart
  /// GradientUtils.gradientText(
  ///   gradient: GradientUtils.primaryGradient,
  ///   child: Text("Glowing text!", style: TextStyle(color: Colors.white)),
  /// )
  /// ```
  static Widget gradientText({required Widget child, Gradient gradient = primaryGradient}) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: child,
    );
  }

  /// Helper rendering a gradient border accurately using a Stack fallback or ShaderMask.
  ///
  /// Example:
  /// ```dart
  /// Container(
  ///   decoration: GradientUtils.gradientBorder(borderRadius: 12),
  ///   child: Text("Nested Inside"),
  /// )
  /// ```
  static BoxDecoration gradientBorder({
    double borderRadius = 12,
    Gradient gradient = primaryGradient,
  }) {
    // Note: Due to Flutter limitations, actual gradient strokes generally require 
    // nested containers (like inside stories_bar), however this utility provides a 
    // convenient box decoration fallback when a gradient background is needed natively.
    return BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }
}

class GlassmorphicEffects {
  /// Constructs a generic responsive Glassmorphic panel implementing a `BackdropFilter` locally.
  ///
  /// Example:
  /// ```dart
  /// GlassmorphicEffects.glassContainer(
  ///   opacity: 0.7,
  ///   blur: 15.0,
  ///   borderRadius: 16.0,
  ///   child: Text("Floating UI", style: TextStyle(color: Colors.white)),
  /// )
  /// ```
  static Widget glassContainer({
    required Widget child,
    double borderRadius = 16.0,
    double opacity = 0.7,
    double blur = 15.0,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.0),
          ),
          child: child,
        ),
      ),
    );
  }

  /// Generic mapping definition applying precise glassmorphism bounding BoxDecorations
  /// natively capable of projecting shadow glows.
  ///
  /// Example:
  /// ```dart
  /// Container(decoration: GlassmorphicEffects.glassDecoration())
  /// ```
  static BoxDecoration glassDecoration({
    double borderRadius = 16.0,
    Color glowColor = AppTheme.primaryPurple,
    double glowOpacity = 0.15,
  }) {
    return BoxDecoration(
      color: AppTheme.surfaceDark,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
      boxShadow: [glowShadow(color: glowColor, opacity: glowOpacity)],
    );
  }

  /// Builds a standard primary gradient action button mapped cleanly reflecting exact loading layouts natively.
  ///
  /// Example:
  /// ```dart
  /// GlassmorphicEffects.gradientButton(
  ///   text: "Submit",
  ///   isLoading: false,
  ///   onPressed: () => print("Submitting"),
  /// )
  /// ```
  static Widget gradientButton({
    required String text,
    required VoidCallback? onPressed,
    double width = double.infinity,
    double height = 50.0,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          gradient: (onPressed == null || isLoading) ? null : GradientUtils.primaryGradient,
          color: (onPressed == null || isLoading) ? AppTheme.surfaceLighter : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(
                  text, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16, 
                    color: (onPressed == null || isLoading) ? AppTheme.textSecondary : Colors.white
                  )
                ),
        ),
      ),
    );
  }

  /// Displays a premium glassmorphic SnackBar with a gradient accent.
  static void showGlassSnackBar(
    BuildContext context, {
    required String message,
    IconData icon = Icons.info_outline,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: glassContainer(
          opacity: 0.8,
          blur: 20,
          borderRadius: 12,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: isError ? Colors.redAccent : AppTheme.primaryPurple,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Produces a precise offset spread lighting layout BoxShadow explicitly glowing
  /// based on standard premium app dimensions dynamically referencing primitive colors correctly.
  ///
  /// Example:
  /// ```dart
  /// Container(decoration: BoxDecoration(boxShadow: [GlassmorphicEffects.glowShadow(color: AppTheme.primaryPink)]))
  /// ```
  static BoxShadow glowShadow({
    required Color color,
    double blurRadius = 15.0,
    double opacity = 0.2,
  }) {
    return BoxShadow(
      color: color.withOpacity(opacity),
      blurRadius: blurRadius,
      spreadRadius: 2,
      offset: const Offset(0, 4),
    );
  }
}

/// Converts raw Firebase and app exceptions into friendly user-facing messages.
class AppErrorHandler {

  /// Auth errors — login, signup, password reset, Google sign-in
  static String authError(dynamic e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('user-not-found') || raw.contains('no user record'))
      return 'No account found with that email.';
    if (raw.contains('wrong-password') || raw.contains('invalid-credential') || raw.contains('invalid-login-credentials'))
      return 'Incorrect username or password. Please try again.';
    if (raw.contains('invalid-email'))
      return 'That doesn\'t look like a valid email address.';
    if (raw.contains('email-already-in-use'))
      return 'An account with this email already exists.';
    if (raw.contains('weak-password'))
      return 'Password must be at least 6 characters.';
    if (raw.contains('too-many-requests') || raw.contains('too many'))
      return 'Too many failed attempts. Please wait a moment and try again.';
    if (raw.contains('network') || raw.contains('timeout') || raw.contains('unavailable'))
      return 'No internet connection. Please check your network and try again.';
    if (raw.contains('user-disabled'))
      return 'This account has been disabled. Please contact support.';
    if (raw.contains('cancelled') || raw.contains('sign_in_canceled'))
      return 'Sign-in was cancelled.';
    if (raw.contains('account-exists-with-different-credential'))
      return 'An account already exists with this email using a different sign-in method.';
    if (raw.contains('popup-closed') || raw.contains('popup_closed'))
      return 'Sign-in window was closed. Please try again.';
    return 'Something went wrong. Please try again.';
  }

  /// Post errors — create, delete, like, repost
  static String postError(dynamic e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('image_too_large')) {
      final parts = e.toString().split(':');
      final size = parts.length >= 3 ? parts[2] : '';
      return 'Image is too large${size.isNotEmpty ? ' ($size)' : ''}. Please choose a smaller image.';
    }
    if (raw.contains('file_too_large')) {
      final parts = e.toString().split(':');
      final size = parts.length >= 3 ? parts[2] : '';
      return 'Video is too large${size.isNotEmpty ? ' ($size)' : ''}. Please trim or compress it first.';
    }
    if (raw.contains('not logged in') || raw.contains('unauthenticated'))
      return 'You need to be logged in to do that.';
    if (raw.contains('unauthorized') || raw.contains('permission-denied'))
      return 'You don\'t have permission to do that.';
    if (raw.contains('already reposted'))
      return 'You\'ve already reposted this.';
    if (raw.contains('network') || raw.contains('unavailable'))
      return 'No internet connection. Please try again.';
    if (raw.contains('not found'))
      return 'This post no longer exists.';
    return 'Something went wrong. Please try again.';
  }

  /// Comment errors
  static String commentError(dynamic e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('not logged in') || raw.contains('unauthenticated'))
      return 'You need to be logged in to comment.';
    if (raw.contains('not found'))
      return 'This post or comment no longer exists.';
    if (raw.contains('unauthorized') || raw.contains('permission-denied'))
      return 'You can only delete your own comments.';
    if (raw.contains('network') || raw.contains('unavailable'))
      return 'No internet connection. Please try again.';
    return 'Something went wrong. Please try again.';
  }

  /// Profile / settings errors
  static String profileError(dynamic e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('image_too_large') || raw.contains('file-too-large'))
      return 'Photo is too large. Please choose a smaller image.';
    if (raw.contains('network') || raw.contains('unavailable'))
      return 'No internet connection. Please try again.';
    if (raw.contains('permission-denied'))
      return 'You don\'t have permission to do that.';
    if (raw.contains('wrong-password') || raw.contains('invalid-credential'))
      return 'Your current password is incorrect.';
    return 'Something went wrong. Please try again.';
  }

  /// Account switch / session errors
  static String switchError(dynamic e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('network') || raw.contains('unavailable'))
      return 'No internet connection. Can\'t switch accounts right now.';
    if (raw.contains('wrong-password') || raw.contains('invalid-credential'))
      return 'Saved password is no longer valid. Please log in manually.';
    if (raw.contains('user-not-found'))
      return 'This saved account no longer exists.';
    if (raw.contains('user-disabled'))
      return 'This account has been disabled.';
    return 'Failed to switch accounts. Please try again.';
  }
}

// @dart=2.12
import 'dart:io';

void main() {
  final files = [
    'lib/screens/home_page.dart',
    'lib/screens/main_screen.dart',
    'lib/screens/profile_screen.dart',
    'lib/screens/profile_menu_screen.dart',
    'lib/screens/settings_screen.dart',
    'lib/screens/comments_screen.dart',
    'lib/screens/messages_screen.dart',
    'lib/screens/notifications_screen.dart',
    'lib/screens/login_screen.dart',
    'lib/screens/sign_up_screen.dart',
    'lib/widgets/post_widget.dart',
    'lib/widgets/create_post_modal.dart',
    'lib/widgets/stories_bar.dart',
    'lib/widgets/friend_recommendations.dart',
    'lib/widgets/app_drawer.dart',
    'lib/widgets/animated_search_bar.dart',
    'lib/widgets/search_results_view.dart',
  ];

  final replacements = {
    'AppTheme.backgroundDark': 'AppTheme.background(context)',
    'AppTheme.surfaceDark': 'AppTheme.surface(context)',
    'AppTheme.surfaceLighter': 'AppTheme.surfaceLight(context)',
    'AppTheme.textPrimary': 'AppTheme.textPrimaryColor(context)',
    'AppTheme.textSecondary': 'AppTheme.textSecondaryColor(context)',
  };

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      print('Not found: $path');
      continue;
    }

    String content = file.readAsStringSync();
    
    // Perform replacements
    bool changed = false;
    for (final entry in replacements.entries) {
      if (content.contains(entry.key)) {
        content = content.replaceAll(entry.key, entry.value);
        changed = true;
      }
    }

    if (changed) {
      final lines = content.split('\n');
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('AppTheme.background(context)') ||
            lines[i].contains('AppTheme.surface(context)') ||
            lines[i].contains('AppTheme.surfaceLight(context)') ||
            lines[i].contains('AppTheme.textPrimaryColor(context)') ||
            lines[i].contains('AppTheme.textSecondaryColor(context)')) {
          lines[i] = lines[i].replaceAll('const ', '');
        }
      }
      content = lines.join('\n');
      
      content = content.replaceAll(RegExp(r'const\s+(TextStyle|Text|Icon|BoxDecoration|BorderSide|Padding|Center|Row|Column|Container|SizedBox|EdgeInsets)'), r'\1');

      file.writeAsStringSync(content);
      print('Updated: $path');
    }
  }
}

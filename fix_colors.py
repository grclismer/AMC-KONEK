import os
import re

files = [
    'lib/screens/home_page.dart',
    'lib/screens/main_screen.dart',
    'lib/screens/profile_screen.dart',
    'lib/screens/profile_menu_screen.dart',
    'lib/screens/settings_screen.dart',
    'lib/screens/kakonek_center_screen.dart',
    'lib/screens/comments_screen.dart',
    'lib/screens/messages_screen.dart',
    'lib/screens/notifications_screen.dart',
    'lib/screens/login_screen.dart',
    'lib/screens/sign_up_screen.dart',
    'lib/screens/forgot_password_screen.dart',
    'lib/screens/privacy_policy_screen.dart',
    'lib/screens/terms_of_service_screen.dart',
    'lib/screens/chat_screen.dart',
    'lib/screens/chat_page.dart',
    'lib/screens/new_message_screen.dart',
    'lib/widgets/post_widget.dart',
    'lib/widgets/create_post_modal.dart',
    'lib/widgets/stories_bar.dart',
    'lib/widgets/friend_recommendations.dart',
    'lib/widgets/app_drawer.dart',
    'lib/widgets/animated_search_bar.dart',
    'lib/widgets/search_results_view.dart',
    'lib/widgets/profile_completion_modal.dart'
]

def repl_text_style(m):
    txt = m.group(0)
    txt = re.sub(r'color:\s*Colors\.white\b', r'color: AppTheme.adaptiveText(context)', txt)
    txt = re.sub(r'color:\s*Colors\.white(?:54|70|60)\b', r'color: AppTheme.adaptiveTextSecondary(context)', txt)
    return txt

def repl_icon(m):
    txt = m.group(0)
    txt = re.sub(r'color:\s*Colors\.white\b', r'color: AppTheme.adaptiveText(context)', txt)
    txt = re.sub(r'color:\s*Colors\.white(?:54|70|60)\b', r'color: AppTheme.adaptiveTextSecondary(context)', txt)
    return txt

for path in files:
    if not os.path.exists(path):
        continue
    
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content
    
    # 1. Direct color names from AppTheme that we previously missed/replaced wrongly
    content = content.replace('color: AppTheme.textSecondaryColor(context)', 'color: AppTheme.adaptiveTextSecondary(context)')
    content = content.replace('color: AppTheme.textPrimaryColor(context)', 'color: AppTheme.adaptiveText(context)')
    content = content.replace('color: AppTheme.textSecondary', 'color: AppTheme.adaptiveTextSecondary(context)')
    content = content.replace('color: AppTheme.textPrimary', 'color: AppTheme.adaptiveText(context)')

    # 2. Colors.white24/12/10 -> adaptiveSubtle
    content = re.sub(r'color:\s*Colors\.white(?:24|12|10)\b', r'color: AppTheme.adaptiveSubtle(context)', content)

    # 3. Apply to TextStyles and Icons using simple brackets matching. We match up to the next parenthesis optionally avoiding internal ones if possible. No, regex isn't a parser. But usually Flutter TextStyle/Icon definitions fit on a few lines and don't contain deep parentheses. 
    # Let's just match anything between TextStyle( and ) non-greedily, EXCEPT if it contains another (.
    content = re.sub(r'TextStyle\([^()]*\)', repl_text_style, content)
    content = re.sub(r'Icon\([^()]*\)', repl_icon, content)

    # Simple revert logic for explicit colors:
    # If the text has 'KONEK', revert.
    content = re.sub(r'(KONEK\x27|\"KONEK\").*?color:\s*AppTheme\.adaptiveText\(context\)', r'\1, style: TextStyle(color: Colors.white)', content, flags=re.DOTALL)

    lines = content.split('\n')
    for i in range(len(lines)):
        # If we see primaryPurple or primaryPink in this line or the previous, let's revert
        if 'AppTheme.adaptiveText(context)' in lines[i] or 'AppTheme.adaptiveTextSecondary' in lines[i]:
            if 'primaryPurple' in lines[i] or 'primaryPink' in lines[i] or 'primaryGradient' in lines[i]:
                lines[i] = lines[i].replace('AppTheme.adaptiveText(context)', 'Colors.white')
                lines[i] = lines[i].replace('AppTheme.adaptiveTextSecondary(context)', 'Colors.white70')
            elif i > 0 and ('primaryPurple' in lines[i-1] or 'primaryPink' in lines[i-1] or 'primaryGradient' in lines[i-1]):
                lines[i] = lines[i].replace('AppTheme.adaptiveText(context)', 'Colors.white')
                lines[i] = lines[i].replace('AppTheme.adaptiveTextSecondary(context)', 'Colors.white70')
                
        # Strip const correctly
        if 'adaptive' in lines[i]:
            lines[i] = re.sub(r'\bconst\s+', '', lines[i])

    content = '\n'.join(lines)
    
    if content != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'Updated: {path}')

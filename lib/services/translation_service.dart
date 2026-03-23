import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_localizations.dart';

class TranslationService {
  static final TranslationService instance = TranslationService._();
  TranslationService._();

  // Uses LibreTranslate public instance — completely free, no API key
  static const String _baseUrl = 'https://libretranslate.com/translate';

  final Map<String, String> _cache = {};

  Future<String?> translate(String text, {String? targetLang}) async {
    final target = targetLang ?? AppLocalizations.instance.languageCode;
    if (target == 'en' && _detectLikelyEnglish(text)) return null;

    final cacheKey = '${text}_$target';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': text,
          'source': 'auto',
          'target': target,
          'format': 'text',
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translated = data['translatedText'] as String?;
        if (translated != null && translated != text) {
          _cache[cacheKey] = translated;
          return translated;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _detectLikelyEnglish(String text) {
    final englishWords = ['the', 'is', 'are', 'was', 'and', 'or', 'to', 'a', 'an', 'i', 'you', 'it'];
    final words = text.toLowerCase().split(' ');
    int matches = words.where((w) => englishWords.contains(w)).length;
    return matches >= 2;
  }
}

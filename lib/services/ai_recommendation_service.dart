import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../Models/place_model.dart';

/// Places the user cares about — used to personalize AI suggestions.
class UserPlaceContext {
  final List<Place> favorites;
  final List<Place> myPlaces;
  final List<Place> catalog;
  final Map<String, String> placeDistances;
  final String currentLocationMessage;

  const UserPlaceContext({
    this.favorites = const [],
    this.myPlaces = const [],
    this.catalog = const [],
    this.placeDistances = const {},
    this.currentLocationMessage = '',
  });

  bool get hasPersonalPlaces => favorites.isNotEmpty || myPlaces.isNotEmpty;

  String toPromptSection() {
    final sections = <String>[];

    if (currentLocationMessage.isNotEmpty) {
      sections.add(currentLocationMessage);
    }

    if (favorites.isNotEmpty) {
      sections.add(
        'Favorite places (user loves these — prioritize similar spots):\n'
        '${_formatPlaces(favorites)}',
      );
    }

    if (myPlaces.isNotEmpty) {
      sections.add(
        'Places the user added (their own discoveries — match this style):\n'
        '${_formatPlaces(myPlaces)}',
      );
    }

    if (catalog.isNotEmpty) {
      sections.add(
        'Other places in the app catalog (only suggest from this list):\n'
        '${_formatPlaces(catalog.take(20))}',
      );
    }

    if (sections.isEmpty) {
      return 'No saved places yet. Ask the user to favorite places or add their own.';
    }

    return sections.join('\n\n');
  }

  String _formatPlaces(Iterable<Place> places) {
    return places
        .map((p) {
          String distStr = '';
          if (placeDistances.containsKey(p.id)) {
            distStr = ', distance ${placeDistances[p.id]}';
          }
          return '- ${p.placeName} (${p.category}, ${p.priceRange}, '
              'rating ${p.rating.toStringAsFixed(1)}$distStr): ${p.description}';
        })
        .join('\n');
  }

  List<Place> rankedCandidates(UserTasteProfile profile) {
    final seen = <String>{};
    final combined = <Place>[];

    void addAll(Iterable<Place> list) {
      for (final place in list) {
        if (seen.add(place.id)) combined.add(place);
      }
    }

    addAll(favorites);
    addAll(myPlaces);
    addAll(catalog);

    combined.sort((a, b) => _score(b, profile).compareTo(_score(a, profile)));
    return combined;
  }

  int _score(Place place, UserTasteProfile profile) {
    var score = (place.rating * 10).round();
    if (favorites.any((p) => p.id == place.id)) score += 50;
    if (myPlaces.any((p) => p.id == place.id)) score += 40;

    final haystack =
        '${place.placeName} ${place.category} ${place.description} ${place.priceRange}'
            .toLowerCase();

    if (profile.placeType != null &&
        haystack.contains(profile.placeType!.split(' ').first)) {
      score += 15;
    }
    if (profile.budget != null) {
      final budget = profile.budget!.toLowerCase();
      if (budget.contains('low') && place.priceRange == r'$') score += 12;
      if (budget.contains('premium') &&
          (place.priceRange == r'$$$' || place.priceRange == r'$$$$')) {
        score += 12;
      }
    }
    return score;
  }
}

class AiRecommendationService {
  static const _apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const _model = 'openrouter/free';

  String get _apiKey => dotenv.env['AI_API_KEY']?.trim() ?? '';

  Future<String> recommend({
    required String userMessage,
    required UserTasteProfile profile,
    required List<({String role, String text})> history,
    required UserPlaceContext placeContext,
    LatLng? userLocation,
  }) async {
    final recentContext = history
        .map((entry) => '${entry.role}: ${entry.text}')
        .join('\n');

    final prompt =
        '''
You are LikeALocal's AI Assistant. Recommend local places in a concise,
friendly chat style (2-4 short paragraphs max).

IMPORTANT:
- Only recommend real places from the lists below. Do not invent place names.
- Prefer favorites and user-added places when they fit the request.
- If suggesting catalog places, pick ones similar in category/vibe to favorites.
- If the user has no saved places or favorites, do NOT say "based on your preferences". Instead, use a phrase like "You do not have preferences yet, but here are some places you may like:" when introducing recommendations. However, still engage in normal conversation if the user is just saying hello or asking a non-recommendation question.

Learned taste profile: ${profile.summary}

User's places:
${placeContext.toPromptSection()}

Recent chat:
$recentContext

User message: $userMessage

Give 2-3 specific recommendations from the lists above. Say why each fits
their favorites or places they added, mention budget/atmosphere when relevant,
and end with one follow-up question.
''';

    try {
      if (_apiKey.isEmpty) {
        return _fallbackRecommendation(userMessage, profile, placeContext);
      }

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://likealocal.app',
              'X-Title': 'LikeALocal',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a smart local travel assistant. Only recommend places provided in the user message context.',
                },
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['choices']?[0]?['message']?['content']
            ?.toString()
            .trim();
        if (content != null && content.isNotEmpty) return content;
      }
    } catch (_) {
      // fall through to local ranking
    }

    return _fallbackRecommendation(userMessage, profile, placeContext);
  }

  String _fallbackRecommendation(
    String message,
    UserTasteProfile profile,
    UserPlaceContext placeContext,
  ) {
    final picks = placeContext.rankedCandidates(profile).take(3).toList();

    if (picks.isEmpty) {
      return 'I do not have any places loaded yet. Favorite a few spots on the map '
          'or add your own places, then ask me again for personalized picks.';
    }

    final atmosphere = profile.atmosphere ?? 'your style';
    final budget = profile.budget ?? 'your budget';
    final buffer = StringBuffer(
      'Based on $atmosphere tastes and $budget, here are picks from your places:\n\n',
    );

    for (var i = 0; i < picks.length; i++) {
      final place = picks[i];
      final source = placeContext.favorites.any((p) => p.id == place.id)
          ? 'one of your favorites'
          : placeContext.myPlaces.any((p) => p.id == place.id)
          ? 'a place you added'
          : 'in our catalog';
      buffer.writeln(
        '${i + 1}. ${place.placeName} ($source) — ${place.category}, '
        '${place.priceRange}. ${place.description}',
      );
    }

    buffer.write('\nWant me to narrow these by distance, food type, or mood?');
    return buffer.toString();
  }
}

class UserTasteProfile {
  String? placeType;
  String? budget;
  String? atmosphere;

  void learnFrom(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('food') ||
        lower.contains('dinner') ||
        lower.contains('coffee') ||
        lower.contains('restaurant')) {
      placeType = 'food and drink spots';
    } else if (lower.contains('gym') || lower.contains('active')) {
      placeType = 'active places';
    } else if (lower.contains('hidden') || lower.contains('local')) {
      placeType = 'hidden gems';
    }

    if (lower.contains('cheap') ||
        lower.contains('budget') ||
        lower.contains('affordable')) {
      budget = 'low budget';
    } else if (lower.contains('fancy') || lower.contains('premium')) {
      budget = 'premium budget';
    }

    if (lower.contains('quiet') || lower.contains('calm')) {
      atmosphere = 'quiet';
    } else if (lower.contains('cozy') || lower.contains('romantic')) {
      atmosphere = 'cozy';
    } else if (lower.contains('fun') || lower.contains('lively')) {
      atmosphere = 'lively';
    }
  }

  String get summary {
    return [
      if (placeType != null) 'preferred place type: $placeType',
      if (budget != null) 'budget: $budget',
      if (atmosphere != null) 'atmosphere: $atmosphere',
      if (placeType == null && budget == null && atmosphere == null)
        'no strong preferences learned yet',
    ].join(', ');
  }
}

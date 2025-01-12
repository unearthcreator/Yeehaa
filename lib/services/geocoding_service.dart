import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:map_mvp_project/services/error_handler.dart';

class GeocodingService {
  static const String accessToken = "pk.eyJ1IjoidW5lYXJ0aGNyZWF0b3IiLCJhIjoiY20yam4yODlrMDVwbzJrcjE5cW9vcDJmbiJ9.L2tmRAkt0jKLd8-fWaMWfA";

  static Future<Map<String, dynamic>?> fetchCoordinatesFromAddress(String address) async {
    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(address)}.json'
      '?access_token=$accessToken'
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      logger.i('Geocoding response: $data');

      if (data['features'] != null && data['features'].isNotEmpty) {
        final feature = data['features'][0];
        final center = feature['center']; // [lng, lat]
        final lng = center[0];
        final lat = center[1];
        logger.i('Coordinates found: lat=$lat, lng=$lng');
        return {'lat': lat, 'lng': lng};
      } else {
        logger.w('No features found for given address.');
        return null;
      }
    } else {
      logger.e('Failed to fetch geocoding data: ${response.statusCode}');
      return null;
    }
  }

  // New method to fetch suggestions based on partial input:
  static Future<List<String>> fetchAddressSuggestions(String query) async {
    if (query.isEmpty) return [];

    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json'
      '?access_token=$accessToken&autocomplete=true&limit=5'
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['features'] != null && data['features'].isNotEmpty) {
        List<String> suggestions = [];
        for (var feature in data['features']) {
          final placeName = feature['place_name'];
          suggestions.add(placeName);
        }
        return suggestions;
      }
    }
    return [];
  }
}
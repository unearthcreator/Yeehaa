/// models/world_config.dart
class WorldConfig {
  /// A unique ID for this world (could be a UUID or similar).
  final String id;

  /// The user’s chosen name/title for the world.
  final String name;

  /// The map type, e.g. "standard" or "satellite".
  final String mapType;

  /// The time mode: "auto" = adjusts light preset after time,
  ///               "manual" = user picks a specific dawn/day/dusk/night.
  final String timeMode;

  /// The manual light preset, if timeMode == "manual".
  /// One of "Dawn"/"Day"/"Dusk"/"Night", or null if timeMode == "auto".
  final String? manualTheme;

  /// Which carousel index this world is associated with.
  final int carouselIndex;

  WorldConfig({
    required this.id,
    required this.name,
    required this.mapType,    // "standard" or "satellite"
    required this.timeMode,   // "auto" or "manual"
    this.manualTheme,         // only relevant if timeMode == "manual"
    required this.carouselIndex,
  });

  /// Factory method to create a default `WorldConfig` for a given index.
  factory WorldConfig.defaultConfig(int index) {
    return WorldConfig(
      id: 'default-$index',         // Unique ID for the default
      name: '',                     // Empty name for a default world
      mapType: 'standard',          // Default map type
      timeMode: 'auto',             // Default time mode
      manualTheme: null,            // No manual theme in "auto" mode
      carouselIndex: index,         // The given index for the carousel
    );
  }

  /// Convert to JSON for storage (e.g. in Hive or another DB).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mapType': mapType,
      'timeMode': timeMode,
      'manualTheme': manualTheme,
      'carouselIndex': carouselIndex,
    };
  }

  /// Reconstruct from a JSON map.
  factory WorldConfig.fromJson(Map<String, dynamic> json) {
    return WorldConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      mapType: json['mapType'] as String,
      timeMode: json['timeMode'] as String,
      manualTheme: json['manualTheme'] as String?,
      carouselIndex: json['carouselIndex'] as int,
    );
  }

  @override
  String toString() {
    return 'WorldConfig('
           'id: $id, '
           'name: $name, '
           'mapType: $mapType, '
           'timeMode: $timeMode, '
           'manualTheme: $manualTheme, '
           'carouselIndex: $carouselIndex'
           ')';
  }
}
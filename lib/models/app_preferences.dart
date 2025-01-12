class AppPreferences {
  final int lastUsedCarouselIndex;
  final String? lastUsedWorldId;
  // ... other fields as needed

  AppPreferences({
    required this.lastUsedCarouselIndex,
    this.lastUsedWorldId,
  });

  Map<String, dynamic> toJson() => {
    'lastUsedCarouselIndex': lastUsedCarouselIndex,
    'lastUsedWorldId': lastUsedWorldId,
    // ...
  };

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    return AppPreferences(
      lastUsedCarouselIndex: json['lastUsedCarouselIndex'] as int,
      lastUsedWorldId: json['lastUsedWorldId'] as String?,
      // ...
    );
  }
}
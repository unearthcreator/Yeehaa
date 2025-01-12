// local_app_preferences.dart
import 'package:hive/hive.dart';

class LocalAppPreferences {
  static const String _boxName = 'appPreferencesBox';

  static Future<Box> _openBox() async {
    return await Hive.openBox(_boxName);
  }

  // lastUsedCarouselIndex
  static Future<void> setLastUsedCarouselIndex(int index) async {
    final box = await _openBox();
    await box.put('lastUsedCarouselIndex', index);
    await box.close();
  }

  static Future<int> getLastUsedCarouselIndex() async {
    final box = await _openBox();
    final stored = box.get('lastUsedCarouselIndex', defaultValue: 4);
    await box.close();
    return stored as int;
  }

}
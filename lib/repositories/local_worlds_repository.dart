import 'package:map_mvp_project/models/world_config.dart';
import 'package:map_mvp_project/repositories/i_world_config_repository.dart';
import 'package:hive/hive.dart';

class LocalWorldsRepository implements IWorldConfigRepository {
  static const String _boxName = 'worldConfigsBox';

  @override
  Future<void> addWorldConfig(WorldConfig config) async {
    final box = await Hive.openBox<Map>(_boxName);
    await box.put(config.id, config.toJson());
    await box.close();
  }

  @override
  Future<WorldConfig?> getWorldConfig(String id) async {
    final box = await Hive.openBox<Map>(_boxName);
    final data = box.get(id);
    await box.close();
    if (data == null) return null;
    return WorldConfig.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<List<WorldConfig>> getAllWorldConfigs() async {
    final box = await Hive.openBox<Map>(_boxName);
    final allValues = box.values.map(
      (mapValue) => WorldConfig.fromJson(Map<String, dynamic>.from(mapValue))
    ).toList();
    await box.close();
    return allValues;
  }

  @override
  Future<void> updateWorldConfig(WorldConfig config) async {
    final box = await Hive.openBox<Map>(_boxName);
    await box.put(config.id, config.toJson());
    await box.close();
  }

  @override
  Future<void> removeWorldConfig(String id) async {
    final box = await Hive.openBox<Map>(_boxName);
    await box.delete(id);
    await box.close();
  }

  /// New method to clear all WorldConfigs in the box.
  /// Great for testing or providing a "reset" feature in the UI.
  Future<void> clearAllWorldConfigs() async {
    final box = await Hive.openBox<Map>(_boxName);
    await box.clear();
    await box.close();
  }
}
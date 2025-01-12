/// repositories/i_world_config_repository.dart

import 'package:map_mvp_project/models/world_config.dart';

/// An interface that describes how to persist and retrieve WorldConfig objects.
/// This is analogous to IAnnotationsRepository, but for user-created "worlds."
abstract class IWorldConfigRepository {
  /// Adds a new WorldConfig to the repository.
  /// - e.g., user just clicked "Save" on EarthCreatorPage
  /// - May assign a unique ID (UUID) if not already set
  Future<void> addWorldConfig(WorldConfig config);

  /// Retrieves a single WorldConfig by [id], or null if not found.
  Future<WorldConfig?> getWorldConfig(String id);

  /// Retrieves all stored WorldConfigs.
  Future<List<WorldConfig>> getAllWorldConfigs();

  /// Updates an existing WorldConfig.
  /// The [config.id] identifies which record to update.
  Future<void> updateWorldConfig(WorldConfig config);

  /// Removes a WorldConfig with the given [id].
  Future<void> removeWorldConfig(String id);
}
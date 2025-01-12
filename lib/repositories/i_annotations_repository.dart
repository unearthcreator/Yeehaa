import 'package:map_mvp_project/models/annotation.dart';

abstract class IAnnotationsRepository {
  /// Adds a new annotation to the repository.
  /// Returns a [Future] that completes when the operation finishes.
  Future<void> addAnnotation(Annotation annotation);

  /// Retrieves all annotations from the repository.
  /// Returns a [Future] that completes with a list of [Annotation].
  Future<List<Annotation>> getAnnotations();

  /// Updates an existing annotation.
  /// The annotation to update is identified by its [id].
  /// Returns a [Future] that completes when the operation finishes.
  Future<void> updateAnnotation(Annotation annotation);

  /// Removes an annotation with the given [id] from the repository.
  /// Returns a [Future] that completes when the operation finishes.
  Future<void> removeAnnotation(String id);
}
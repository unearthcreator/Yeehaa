import 'package:map_mvp_project/models/annotation.dart';
import 'package:map_mvp_project/repositories/i_annotations_repository.dart';
import 'package:hive/hive.dart';

class LocalAnnotationsRepository implements IAnnotationsRepository {
  static const String _boxName = 'annotationsBox';

  // Opens the Hive box that stores annotations as Maps (from annotation.toJson()).
  Future<Box<Map>> _openBox() async {
    // Using a Box<Map> since we store the annotation data as a Map.
    return await Hive.openBox<Map>(_boxName);
  }

  @override
  Future<void> addAnnotation(Annotation annotation) async {
    final box = await _openBox();
    await box.put(annotation.id, annotation.toJson());
  }

  @override
  Future<List<Annotation>> getAnnotations() async {
    final box = await _openBox();
    // Convert each map into Map<String,dynamic> before passing to fromJson
    return box.values
        .map((map) => Annotation.fromJson(Map<String, dynamic>.from(map)))
        .toList();
  }

  @override
  Future<void> updateAnnotation(Annotation annotation) async {
    final box = await _openBox();
    await box.put(annotation.id, annotation.toJson());
  }

  @override
  Future<void> removeAnnotation(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }
}
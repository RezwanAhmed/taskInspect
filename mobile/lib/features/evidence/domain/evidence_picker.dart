import 'package:equatable/equatable.dart';

/// Takes or chooses evidence files. The app uses the device camera,
/// gallery and file picker; tests use a fake.
abstract interface class EvidencePicker {
  /// Opens the camera. Returns the photo's file path, or `null` when the
  /// worker cancels.
  Future<String?> takePhoto();

  /// Opens the gallery. Returns the photo's file path, or `null`.
  Future<String?> chooseFromGallery();

  /// Opens the device's files to choose a PDF document, or `null`.
  Future<PickedDocument?> chooseDocument();
}

/// A document chosen by the worker: a readable local file and its name.
class PickedDocument extends Equatable {
  const PickedDocument({required this.path, required this.name});

  final String path;
  final String name;

  @override
  List<Object?> get props => [path, name];
}

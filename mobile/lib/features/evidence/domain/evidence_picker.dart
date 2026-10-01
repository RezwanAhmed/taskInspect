/// Takes or chooses evidence files. The app uses the device camera and
/// gallery; tests use a fake.
abstract interface class EvidencePicker {
  /// Opens the camera. Returns the photo's file path, or `null` when the
  /// worker cancels.
  Future<String?> takePhoto();

  /// Opens the gallery. Returns the photo's file path, or `null`.
  Future<String?> chooseFromGallery();
}

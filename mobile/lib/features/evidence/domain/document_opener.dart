/// Shows a stored document in an app on the device (e.g. the PDF viewer).
abstract interface class DocumentOpener {
  /// Opens the file at [path]. Returns `false` when no app can open it.
  Future<bool> open(String path, {required String mimeType});
}

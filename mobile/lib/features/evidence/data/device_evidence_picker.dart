import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:taskinspect/features/evidence/domain/evidence_picker.dart';

/// [EvidencePicker] with the device camera and gallery (image_picker) and
/// file picker (file_picker), on Android and iOS. The camera and
/// photo-library permission texts for iOS are in Info.plist.
class DeviceEvidencePicker implements EvidencePicker {
  DeviceEvidencePicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> takePhoto() async => (await _picker.pickImage(source: ImageSource.camera))?.path;

  @override
  Future<String?> chooseFromGallery() async => (await _picker.pickImage(source: ImageSource.gallery))?.path;

  @override
  Future<PickedDocument?> chooseDocument() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
    if (file == null) {
      return null;
    }
    var path = file.path;
    if (path == null) {
      // Not a local file (e.g. a cloud document): copy it to a temporary file first.
      path = p.join((await getTemporaryDirectory()).path, 'picked-${DateTime.now().microsecondsSinceEpoch}.pdf');
      await file.xFile.saveTo(path);
    }
    return PickedDocument(path: path, name: file.name);
  }
}

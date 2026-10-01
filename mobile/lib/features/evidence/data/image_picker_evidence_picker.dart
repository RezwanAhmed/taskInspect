import 'package:image_picker/image_picker.dart';
import 'package:taskinspect/features/evidence/domain/evidence_picker.dart';

/// [EvidencePicker] with the image_picker plugin (Android and iOS). The
/// camera and photo-library permission texts for iOS are in Info.plist.
class ImagePickerEvidencePicker implements EvidencePicker {
  ImagePickerEvidencePicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> takePhoto() async => (await _picker.pickImage(source: ImageSource.camera))?.path;

  @override
  Future<String?> chooseFromGallery() async => (await _picker.pickImage(source: ImageSource.gallery))?.path;
}

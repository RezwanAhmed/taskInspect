import 'package:open_filex/open_filex.dart';
import 'package:taskinspect/features/evidence/domain/document_opener.dart';

/// [DocumentOpener] with the open_filex plugin (Android and iOS).
class OpenFilexDocumentOpener implements DocumentOpener {
  const OpenFilexDocumentOpener();

  @override
  Future<bool> open(String path, {required String mimeType}) async {
    final result = await OpenFilex.open(path, type: mimeType);
    return result.type == ResultType.done;
  }
}

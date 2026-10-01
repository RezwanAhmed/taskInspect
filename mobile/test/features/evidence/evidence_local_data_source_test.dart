import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/features/evidence/data/image_compressor.dart';
import 'package:taskinspect/features/evidence/data/local/evidence_local_data_source.dart';
import 'package:taskinspect/features/tasks/data/local/task_local_data_source.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../helpers/fake_tasks.dart';

/// Pretends to compress: returns the first half of the file.
class _HalfCompressor implements ImageCompressor {
  int calls = 0;

  @override
  Future<Uint8List> compressToJpeg(String path) async {
    calls++;
    final bytes = await File(path).readAsBytes();
    return Uint8List.sublistView(bytes, 0, bytes.length ~/ 2);
  }
}

void main() {
  late AppDatabase db;
  late Directory documents;
  late Directory picked;
  late _HalfCompressor compressor;
  late EvidenceLocalDataSource evidence;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    documents = await Directory.systemTemp.createTemp('documents');
    picked = await Directory.systemTemp.createTemp('picked');
    compressor = _HalfCompressor();
    evidence = EvidenceLocalDataSource(db, compressor, documentsDirectory: () async => documents);
    await TaskLocalDataSource(db).saveTask(fakeTask('t1', status: TaskStatus.inProgress), const [
      Requirement(id: 'r1', taskId: 't1', title: 'Photo', type: RequirementType.photo, required: true, position: 0),
    ]);
  });

  tearDown(() async {
    await db.close();
    await documents.delete(recursive: true);
    await picked.delete(recursive: true);
  });

  Future<String> pickedPhoto(String name) async {
    final file = File('${picked.path}/$name');
    await file.writeAsBytes(List.filled(1000, 7));
    return file.path;
  }

  test('compresses the photo and stores it in the app files, waiting for upload', () async {
    final item = await evidence.addPhoto(taskId: 't1', requirementId: 'r1', sourcePath: await pickedPhoto('a.jpg'));

    expect(compressor.calls, 1);
    expect(item.sizeBytes, 500);
    expect(item.mimeType, 'image/jpeg');
    expect(item.uploaded, isFalse);
    expect(item.localPath, startsWith(documents.path));
    expect(item.localPath, endsWith('${item.id}.jpg'));
    expect(await File(item.localPath).length(), 500);
  });

  test('photos are listed per requirement in the order they were added', () async {
    final first = await evidence.addPhoto(taskId: 't1', requirementId: 'r1', sourcePath: await pickedPhoto('a.jpg'));
    final second = await evidence.addPhoto(taskId: 't1', requirementId: 'r1', sourcePath: await pickedPhoto('b.jpg'));

    final stored = await evidence.watchEvidence('t1').first;

    expect(stored['r1']!.map((e) => e.id), [first.id, second.id]);
    expect(first.id, isNot(second.id));
  });

  test('if recording fails, the copied file is removed again', () async {
    // A requirement that does not exist breaks the foreign key.
    await expectLater(
      evidence.addPhoto(taskId: 't1', requirementId: 'missing', sourcePath: await pickedPhoto('a.jpg')),
      throwsA(anything),
    );

    final files = Directory('${documents.path}/evidence/t1').listSync();
    expect(files, isEmpty);
  });
}

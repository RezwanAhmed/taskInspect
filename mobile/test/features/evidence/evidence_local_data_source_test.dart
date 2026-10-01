import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/features/evidence/data/image_compressor.dart';
import 'package:taskinspect/features/evidence/data/local/evidence_local_data_source.dart';
import 'package:taskinspect/features/evidence/domain/evidence_repository.dart';
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
      Requirement(id: 'r2', taskId: 't1', title: 'Report', type: RequirementType.document, required: true, position: 1),
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

  test('removing deletes the record and the file', () async {
    final item = await evidence.addPhoto(taskId: 't1', requirementId: 'r1', sourcePath: await pickedPhoto('a.jpg'));

    await evidence.remove(item);

    expect(await evidence.watchEvidence('t1').first, isEmpty);
    expect(File(item.localPath).existsSync(), isFalse);
  });

  Future<String> pickedFile(String name, List<int> bytes) async {
    final file = File('${picked.path}/$name');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  test('a PDF document is copied unchanged and keeps its name', () async {
    final content = [...'%PDF-1.7\n'.codeUnits, ...List.filled(300, 1)];
    final source = await pickedFile('report.pdf', content);

    final item = await evidence.addDocument(
      taskId: 't1',
      requirementId: 'r2',
      sourcePath: source,
      fileName: 'Service report.pdf',
    );

    expect(compressor.calls, 0);
    expect(item.mimeType, 'application/pdf');
    expect(item.sizeBytes, content.length);
    expect(item.localPath, endsWith('${item.id}.pdf'));
    expect(await File(item.localPath).readAsBytes(), content);
    expect(File(source).existsSync(), isTrue);
    final stored = await evidence.watchEvidence('t1').first;
    expect(stored['r2']!.single.fileName, 'Service report.pdf');
  });

  test('files that are not PDFs or too large are rejected and not stored', () async {
    final notPdf = await pickedFile('fake.pdf', 'hello'.codeUnits);
    final empty = await pickedFile('empty.pdf', const []);
    final huge = File('${picked.path}/huge.pdf');
    final raf = await huge.open(mode: FileMode.write);
    await raf.writeFrom('%PDF-'.codeUnits);
    await raf.setPosition(20 * 1024 * 1024);
    await raf.writeByte(1);
    await raf.close();

    for (final path in [notPdf, empty, huge.path]) {
      await expectLater(
        evidence.addDocument(taskId: 't1', requirementId: 'r2', sourcePath: path, fileName: 'x.pdf'),
        throwsA(isA<EvidenceRejected>()),
      );
    }
    expect(await evidence.watchEvidence('t1').first, isEmpty);
    expect(Directory('${documents.path}/evidence/t1').existsSync(), isFalse);
  });

  test('sign out deletes all evidence files', () async {
    final item = await evidence.addPhoto(taskId: 't1', requirementId: 'r1', sourcePath: await pickedPhoto('a.jpg'));

    await evidence.deleteAllFiles();

    expect(File(item.localPath).existsSync(), isFalse);
    expect(Directory('${documents.path}/evidence').existsSync(), isFalse);
  });
}

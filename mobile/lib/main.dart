import 'package:flutter/material.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const TaskInspectApp());
}

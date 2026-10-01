import 'package:flutter/material.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/synchronization/sync_scheduler.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  // Changes are synchronized while someone is signed in.
  final sync = getIt<SyncScheduler>();
  getIt<AuthBloc>().stream.listen((state) => state is Authenticated ? sync.start() : sync.stop());
  runApp(const TaskInspectApp());
}

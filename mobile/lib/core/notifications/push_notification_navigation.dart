import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/core/router/app_router.dart';

/// Handles a data-only message while the app is backgrounded (Android
/// requires a top-level handler to be registered even when there is
/// nothing to do - the OS shows the notification itself from the message's
/// `notification` block).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Opens the tapped notification's task (background/terminated via
/// [FirebaseMessaging.onMessageOpenedApp] and [FirebaseMessaging.getInitialMessage])
/// and shows a banner for one that arrives while the app is open
/// (task 8.7). Call once when the app starts.
void setUpPushNotificationNavigation() {
  FirebaseMessaging.onMessage.listen(_showForegroundBanner);
  FirebaseMessaging.onMessageOpenedApp.listen(_openTask);
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) {
      _openTask(message);
    }
  });
}

void _openTask(RemoteMessage message) {
  final taskId = message.data['taskId'] as String?;
  final context = rootNavigatorKey.currentContext;
  if (taskId == null || context == null) {
    return;
  }
  GoRouter.of(context).go(AppRoutes.task(taskId));
}

void _showForegroundBanner(RemoteMessage message) {
  final title = message.notification?.title;
  final context = rootNavigatorKey.currentContext;
  if (title == null || context == null) {
    return;
  }
  final taskId = message.data['taskId'];
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(title),
    action: taskId == null ? null : SnackBarAction(label: 'View', onPressed: () => _openTask(message)),
  ));
}

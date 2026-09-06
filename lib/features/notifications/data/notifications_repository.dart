import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Push notifications: asking for them, registering the device, and turning a
/// tapped notification into a route.
///
/// An auction without "you've been outbid" is a feature people use once, so
/// this is not optional polish — but everything here degrades quietly. A
/// member who declines the permission, or whose token never arrives, still has
/// a working app; they just have to look.
class NotificationsRepository {
  NotificationsRepository({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>>? _devicesOf(String uid) =>
      uid.isEmpty
      ? null
      : _firestore.collection('users').doc(uid).collection('devices');

  /// Asks for permission and registers this device.
  ///
  /// Called after sign-in rather than at launch: a permission prompt on the
  /// very first screen, before anybody knows what the app is, is the fastest
  /// way to have it denied forever.
  Future<void> start() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await _messaging.getToken();
      if (token != null) await _register(uid, token);

      // Tokens rotate — on reinstall, on restore, and occasionally for no
      // visible reason. Without this the app would keep pushing to a token
      // FCM has already retired.
      _messaging.onTokenRefresh.listen((next) {
        final currentUid = _auth.currentUser?.uid;
        if (currentUid != null) _register(currentUid, next);
      });
    } catch (error) {
      // A device with no Play services, a simulator, a declined prompt: none
      // of them is a reason to break the app.
      debugPrint('Push notifications unavailable: $error');
    }
  }

  Future<void> _register(String uid, String token) async {
    final devices = _devicesOf(uid);
    if (devices == null) return;

    await devices.doc(token).set({
      'platform': _platform,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }

  /// Removes this device on sign-out.
  ///
  /// Without it, the next person to sign in on a shared phone keeps receiving
  /// the last one's outbid notifications.
  Future<void> stop() async {
    final uid = _auth.currentUser?.uid;

    try {
      final token = await _messaging.getToken();
      if (uid != null && token != null) {
        await _devicesOf(uid)?.doc(token).delete();
      }
      await _messaging.deleteToken();
    } catch (error) {
      debugPrint('Could not release the push token: $error');
    }
  }

  /// A notification tapped while the app was running.
  Stream<NotificationTap> get onTap =>
      FirebaseMessaging.onMessageOpenedApp.map(NotificationTap.fromMessage);

  /// The notification that launched the app, if one did.
  Future<NotificationTap?> initialTap() async {
    try {
      final message = await _messaging.getInitialMessage();
      return message == null ? null : NotificationTap.fromMessage(message);
    } catch (_) {
      return null;
    }
  }
}

/// Where a tapped notification wants to go.
///
/// The server sends `kind` and `id` as data rather than putting them in the
/// visible notification, so the routing survives whatever the OS decides to
/// show.
class NotificationTap {
  const NotificationTap({required this.kind, required this.id});

  final String kind;
  final String id;

  factory NotificationTap.fromMessage(RemoteMessage message) {
    return NotificationTap(
      kind: message.data['kind']?.toString() ?? '',
      id: message.data['id']?.toString() ?? '',
    );
  }

  /// The in-app location, or null when the payload means nothing to this
  /// build — a newer server can send a kind this version has never heard of,
  /// and opening the app is a better answer than crashing on it.
  String? get route => switch (kind) {
    'auction' when id.isNotEmpty => '/bid-room/$id',
    'chat' when id.isNotEmpty => '/chat',
    _ => null,
  };
}

import 'dart:async';

import 'package:on_this_day_mobile/core/notifications/notification_prompt_coordinator.dart';
import 'package:on_this_day_mobile/core/notifications/notification_prompt_store.dart';
import 'package:on_this_day_mobile/core/notifications/notification_service.dart';
import 'package:on_this_day_mobile/core/notifications/registered_token_store.dart';

class FakePermissionGateway implements NotificationPermissionGateway {
  FakePermissionGateway({
    this.status = NotificationPermissionStatus.notDetermined,
    this.requestResult = NotificationPermissionStatus.authorized,
    this.statusError,
    this.requestError,
  });

  NotificationPermissionStatus status;
  NotificationPermissionStatus requestResult;
  Object? statusError;
  Object? requestError;

  /// When set, requestPermission waits for this to complete (simulates the
  /// system dialog staying open).
  Completer<void>? pendingRequest;

  int statusReadCount = 0;
  int requestCount = 0;

  @override
  Future<NotificationPermissionStatus> currentPermissionStatus() async {
    statusReadCount += 1;
    final error = statusError;
    if (error != null) throw error;
    return status;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    requestCount += 1;
    final pending = pendingRequest;
    if (pending != null) await pending.future;
    final error = requestError;
    if (error != null) throw error;
    status = requestResult;
    return requestResult;
  }
}

class InMemoryPromptStore implements NotificationPromptStore {
  InMemoryPromptStore({this.record, this.readError, this.writeError});

  NotificationPromptRecord? record;
  Object? readError;
  Object? writeError;
  final List<NotificationPromptRecord> writes = [];

  @override
  Future<NotificationPromptRecord?> read() async {
    final error = readError;
    if (error != null) throw error;
    return record;
  }

  @override
  Future<void> write(NotificationPromptRecord value) async {
    final error = writeError;
    if (error != null) throw error;
    writes.add(value);
    record = value;
  }
}

/// A controllable clock for cooldown tests.
class FakeClock {
  FakeClock([DateTime? start]) : now = start ?? DateTime.utc(2026, 9, 1, 12);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) => now = now.add(duration);
}

class RecordingRegistration {
  final List<NotificationPermissionStatus> calls = [];
  Object? error;

  /// When set, registration waits for this (simulates slow network).
  Completer<void>? pending;

  Future<void> call(NotificationPermissionStatus status) async {
    calls.add(status);
    final wait = pending;
    if (wait != null) await wait.future;
    final failure = error;
    if (failure != null) throw failure;
  }
}

NotificationPromptCoordinator promptCoordinator({
  FakePermissionGateway? permissions,
  InMemoryPromptStore? store,
  RecordingRegistration? registration,
  bool deniedMayBeUnasked = false,
  DateTime Function()? now,
}) {
  final recorder = registration ?? RecordingRegistration();
  return NotificationPromptCoordinator(
    permissions: permissions ?? FakePermissionGateway(),
    store: store ?? InMemoryPromptStore(),
    onAuthorized: recorder.call,
    deniedMayBeUnasked: deniedMayBeUnasked,
    now: now,
  );
}

class InMemoryRegisteredTokenStore implements RegisteredTokenStore {
  InMemoryRegisteredTokenStore({this.token});

  String? token;
  Object? readError;
  final List<String> events = [];

  @override
  Future<String?> read() async {
    final error = readError;
    if (error != null) throw error;
    return token;
  }

  @override
  Future<void> write(String value) async {
    events.add('write');
    token = value;
  }

  @override
  Future<void> clear() async {
    events.add('clear');
    token = null;
  }
}

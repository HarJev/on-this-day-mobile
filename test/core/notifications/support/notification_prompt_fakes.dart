import 'dart:async';

import 'package:on_this_day_mobile/core/notifications/notification_prompt_coordinator.dart';
import 'package:on_this_day_mobile/core/notifications/notification_prompt_store.dart';
import 'package:on_this_day_mobile/core/notifications/notification_service.dart';

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
  InMemoryPromptStore({this.decision, this.readError, this.writeError});

  NotificationPromptDecision? decision;
  Object? readError;
  Object? writeError;
  final List<NotificationPromptDecision> writes = [];

  @override
  Future<NotificationPromptDecision?> read() async {
    final error = readError;
    if (error != null) throw error;
    return decision;
  }

  @override
  Future<void> write(NotificationPromptDecision value) async {
    final error = writeError;
    if (error != null) throw error;
    writes.add(value);
    decision = value;
  }
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
}) {
  final recorder = registration ?? RecordingRegistration();
  return NotificationPromptCoordinator(
    permissions: permissions ?? FakePermissionGateway(),
    store: store ?? InMemoryPromptStore(),
    onAuthorized: recorder.call,
    deniedMayBeUnasked: deniedMayBeUnasked,
  );
}

library firebase_presence;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// A widget that observes and collects detailed lifecycle and connection data
/// of an app and its users activity then reports it to Firebase Realtime database.
/// This can be useful in the case of user presence (online/offline status)
/// while also checking how or if a user is focused on the app itself.
///
/// Lifecycle data is determined by `WidgetsBindingObserver` while user presence
/// relies solely on a `FirebaseDatabase` instance to provide its connection state.
class FirebasePresence extends StatefulWidget {
  /// A widget that observes and collects detailed lifecycle and connection data
  /// of an app and its users activity then reports it to Firebase Realtime database.
  /// This can be useful in the case of user presence (online/offline status)
  /// while also checking how or if a user is focused on the app itself.
  ///
  /// Lifecycle data is determined by `WidgetsBindingObserver` while user presence
  /// relies solely on a `FirebaseDatabase` instance to provide its connection state.
  const FirebasePresence({
    super.key,
    required this.databaseReference,
    required this.child,
    this.setLifeCycleState = true,
    this.autoDispose = true,
    this.onInactiveCallback,
    this.onPausedCallback,
    this.onResumedCallback,
    this.onDetachedCallback,
    this.onErrorCallback,
    this.errorBuilder,
  });

  /// A `DatabaseReference` object representing the path to store presence data.
  final DatabaseReference databaseReference;

  /// A child widget.
  final Widget child;

  /// Whether or not to set the lifecycle state in the realtime database.
  final bool setLifeCycleState;

  /// Whether or not to dispose the lifecycle state listener.
  final bool autoDispose;

  /// Called when the widget lifecycle event is inactive.
  /// See `AppLifecycleState` documentation to learn more about these states.
  final void Function()? onInactiveCallback;

  /// Called when the widget lifecycle event is detached.
  /// See `AppLifecycleState` documentation to learn more about these states.
  final void Function()? onDetachedCallback;

  /// Called when the widget lifecycle event is paused.
  /// See `AppLifecycleState` documentation to learn more about these states.
  final void Function()? onPausedCallback;

  /// Called when the widget lifecycle event is resumed.
  /// See `AppLifecycleState` documentation to learn more about these states.
  final void Function()? onResumedCallback;

  /// Called when an error occurs.
  final void Function(Object? error, StackTrace? stackTrace)? onErrorCallback;

  /// The widget to display when an error occurs.
  final Widget Function(Object? error, StackTrace? stackTrace)? errorBuilder;

  @override
  FirebasePresenceState createState() => FirebasePresenceState();
}

class FirebasePresenceState extends State<FirebasePresence>
    with WidgetsBindingObserver {
  FirebasePresenceWidgetState _state = FirebasePresenceWidgetState.init;

  late FirebasePresenceData _firebasePresenceData;

  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void setState(fn) {
    super.setState(fn);
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    super.dispose();
    widget.autoDispose ? WidgetsBinding.instance.removeObserver(this) : null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    _error = null;
    try {
      // Switch over `AppLifecycleState` and set in RTDB.
      switch (state) {
        case AppLifecycleState.inactive:
          widget.onInactiveCallback?.call();
          await _setLifeCycleState(FirebasePresenceWidgetState.inactive);
          break;
        case AppLifecycleState.resumed:
          widget.onResumedCallback?.call();
          await _setLifeCycleState(FirebasePresenceWidgetState.resumed);
          break;
        case AppLifecycleState.paused:
          widget.onPausedCallback?.call();
          await _setLifeCycleState(FirebasePresenceWidgetState.paused);
          break;
        case AppLifecycleState.detached:
          widget.onDetachedCallback?.call();
          await _setLifeCycleState(FirebasePresenceWidgetState.detached);
          break;
      }
    } catch (e, s) {
      _error = e;
      _stackTrace = s;
      setState(() {
        _state = FirebasePresenceWidgetState.error;
      });
      widget.onErrorCallback?.call(e, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == FirebasePresenceWidgetState.error) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error, _stackTrace);
      } else {
        return widget.child;
      }
    } else {
      return widget.child;
    }
  }

  /// Sets presence data in the RTDB.
  Future<void> _setPresence({
    required bool isOnline,
    required String userId,
    required String? appLifeCycle,
  }) async {
    try {
      await widget.databaseReference.child(userId).set({
        'isOnline': isOnline,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
        'appLifeCycle': appLifeCycle,
      });
    } catch (e, s) {
      _error = e;
      _stackTrace = s;
      setState(() {
        _state = FirebasePresenceWidgetState.error;
      });
      widget.onErrorCallback?.call(e, s);
    }
  }

  /// Initialises listeners while also setting an initial state for
  /// both online/offline status and the app lifecycle.
  Future<void> _initialize() async {
    final auth = FirebaseAuth.instance;
    try {
      // Set presence on app startup since Firebase Auth persists authentication.
      // Also sets the listener for when the user disconnects from RTDB.
      if (auth.currentUser?.uid != null) {
        await _setPresence(
            isOnline: true,
            userId: auth.currentUser!.uid,
            appLifeCycle: AppLifecycleState.resumed.name);
        // Callback on disconnect sets the users presence to false along with
        // last seen time.
        await widget.databaseReference
            .child(auth.currentUser!.uid)
            .onDisconnect()
            .set({
          'isOnline': false,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
          'appLifeCycle': AppLifecycleState.detached.name,
        });
      }
      // Listen for auth state changes and update presence on events.
      auth.authStateChanges().listen((event) async {
        if (auth.currentUser?.uid != null) {
          await _setPresence(
              isOnline: true,
              userId: auth.currentUser!.uid,
              appLifeCycle: AppLifecycleState.resumed.name);
        }
      });
    } catch (e, s) {
      _error = e;
      _stackTrace = s;
      setState(() {
        _state = FirebasePresenceWidgetState.error;
      });
      widget.onErrorCallback?.call(e, s);
    }
  }

  /// Independently updates the life cycle state, seprately to the online/offline state.
  Future<void> _setLifeCycleState(FirebasePresenceWidgetState state) async {
    if (widget.setLifeCycleState) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          await widget.databaseReference.child(currentUser.uid).update({
            'appLifeCycle': state.name,
          });
        } catch (e, s) {
          setState(() {
            _state = FirebasePresenceWidgetState.error;
          });
          widget.onErrorCallback?.call(e, s);
        }
      }
    }
  }
}

/// Represents the various lifecycle states of a `FirebasePresence` widget.
enum FirebasePresenceWidgetState {
  /// Indicates that the widget has initialised its data.
  init,

  /// Indicates an inactive lifecycle state for this widget.
  inactive,

  /// Indicates a paused lifecycle state for this widget.
  paused,

  /// Indicates a resumed lifecycle state for this widget.
  resumed,

  /// Indicates a detached lifecycle state for this widget.
  detached,

  /// Indicates an error occured when sending or receiving data to/from the RTDB.
  error,

  /// Indicates that the data received from the RTDB was null.
  Null,
}

/// A widget that fetches presence data collected by a `FirebasePresence` instance used
/// on client devices.
///
/// This can be useful in the case of user presence (online/offline status)
/// while also checking how or if a user is focused on the app itself.
class FirebasePresenceBuilder extends StatefulWidget {
  /// A widget that fetches presence data collected by a `FirebasePresence` instance used
  /// on client devices.
  ///
  /// This can be useful in the case of user presence (online/offline status)
  /// while also checking how or if a user is focused on the app itself.
  const FirebasePresenceBuilder({
    super.key,
    required this.databaseReference,
    required this.builder,
    this.onError,
    required this.userId,
  });

  /// A `DatabaseReference` object representing the path to store presence data.
  final DatabaseReference databaseReference;

  /// The widget to show when data is received from the RTDB.
  final Widget Function(FirebasePresenceData? data) builder;

  /// The widget to be displayed when receiving data from the RTDB.
  final Widget Function(Object? error, StackTrace? stackTrace)? onError;

  /// The user ID of the user to check presence for.
  final String userId;

  @override
  FirebasePresenceBuilderState createState() => FirebasePresenceBuilderState();
}

class FirebasePresenceBuilderState extends State<FirebasePresenceBuilder> {
  FirebasePresenceData? _firebasePresenceData;
  Object? _error;
  StackTrace? _stackTrace;
  FirebasePresenceWidgetState _state = FirebasePresenceWidgetState.init;

  init() {
    widget.databaseReference.onValue.listen((event) {
      setState(() {
        final user =
            (event.snapshot.value as Map<dynamic, dynamic>?)?[widget.userId];
        if (user != null) {
          _firebasePresenceData = FirebasePresenceData(
            isOnline: user['isOnline'],
            lastSeen: user['lastSeen'],
            appLifeCycle: user['appLifeCycle'],
          );
          _state = FirebasePresenceWidgetState.resumed;
        } else {
          setState(() {
            _state = FirebasePresenceWidgetState.Null;
          });
        }
      });
    }).onError((e, s) {
      setState(() {
        _error = e;
        _stackTrace = s;
        _state = FirebasePresenceWidgetState.error;
      });
    });
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      init();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_state == FirebasePresenceWidgetState.init &&
        _firebasePresenceData != null) {
      return widget.builder(_firebasePresenceData!);
    } else if (_state == FirebasePresenceWidgetState.resumed &&
        _firebasePresenceData != null) {
      return widget.builder(_firebasePresenceData!);
    } else if (_state == FirebasePresenceWidgetState.error &&
        widget.onError != null) {
      return widget.onError!.call(_error, _stackTrace);
    } else {
      return widget.builder.call(null);
    }
  }
}

/// An object representing the data collected by a `FirebasePresence` instance.
class FirebasePresenceData {
  /// An object representing the data collected by a `FirebasePresence` instance.
  FirebasePresenceData({
    required this.isOnline,
    required this.lastSeen,
    required this.appLifeCycle,
  });

  /// Whether or not the user is online/offline.
  final bool isOnline;

  /// The last seen time of the user in epoch unix time, it milliseconds.
  final int lastSeen;

  /// The last known app lifecycle state for the user.
  final String appLifeCycle;

  factory FirebasePresenceData.fromJson(Map<String, dynamic> json) =>
      FirebasePresenceData(
        isOnline: json['isOnline'],
        lastSeen: json['lastSeen'],
        appLifeCycle: json['appLifeCycle'],
      );
}

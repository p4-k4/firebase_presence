# FirebasePresence

An all-in-one solution that observes and collects detailed lifecycle and connection data
of an app and its users activity, then reports it to Firebase Realtime database.
This can be useful in the case of user presence (online/offline status)
while also checking how or if a user is focused on the app itself.

## Features
- Push/Get (in realtime) presence (online/offline) state to RTDB.
- Push/Get (in realtime) lifecycle state data to RTDB (optional).
- Specify a Firebase user for presence/lifeycle data.
- Lifecycle state callbacks.
- Optional Error handling.
- Optional auto-dispose.

## How?
Lifecycle data is determined by `WidgetsBindingObserver` while user presence
relies solely on a `FirebaseDatabase` instance to provide its connection state.

## Quickstart
Wrap your `MaterialApp` widget in a `FirebasePresence` widget and let it do the rest.

You may also consider wrapping specific views/widgets in a `FirebasePresence` widget to target
specific views within your app where you require specific presence and lifecycle data
that pertains to a certain view within your app. If this is the case, providing a unique
`DatabaseReference` can help to isolate that data when it's written to the Firebase Realtime Database.

```dart
FirebasePresence(
  setLifeCycleState: true,
  autoDispose: true,
  databaseReference: database.ref('presence'),
  onDetachedCallback: () => print('Detached.'),
  onInactiveCallback: () => print('Inactive.'),
  onResumedCallback: () => print('Resumed.'),
  onPausedCallback: () => print('Paused.'),
  onErrorCallback: (e, s) => print(e),
  errorBuilder: (error, stackTrace) => const Text('Error'),
  child: MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Presence'),
      ),
      body: FirebasePresenceBuilder(
        userId: auth.currentUser!.uid,
        databaseReference: database.ref('presence'),
        onError: (e, s) => Text(e.toString()),
        builder: (data) => data != null
            ? Column(
                children: [
                  Text(data.isOnline.toString()),
                  Text(data.lastSeen.toString()),
                  Text(data.appLifeCycle.toString()),
                ],
              )
            : const Text('No data.'),
      ),
    ),
  ),
);
```

## `FirebasePresence`

A widget that observes and collects detailed lifecycle and connection data of an app and its users activity then reports it to Firebase Realtime database.

This can be useful in the case of user presence (online/offline status) while also checking how or if a user is focused on the app itself.

Lifecycle data is determined by `WidgetsBindingObserver` while user presence relies solely on a `FirebaseDatabase` instance to provide its connection state.

### Parameters
- `setLifeCycleState` - Whether or not to set the lifecycle state in the realtime database.
- `autoDispose` - Whether or not to dispose the lifecycle state listener.
- `databaseReference` - A `DatabaseReference` object representing the path to store presence data.
- `onDetachedCallback` - Called when the widget lifecycle event is detached.
- `onInactiveCallback` - Called when the widget lifecycle event is inactive.
- `onResumedCallback` - Called when the widget lifecycle event is resumed.
- `onPausedCallback` - Called when the widget lifecycle event is paused.
- `onErrorCallback` - Called when an error occurs.
- `errorBuilder` - The widget to display when an error occurs.
- `child` - A child widget.

## `FirebasePresenceBuilder`

A widget that fetches presence data collected by a `FirebasePresence` instance used on client devices.

This can be useful in the case of user presence (online/offline status) while also checking how or if a user is focused on the app itself.

### Parameters
- `userId` - The user ID of the user to check presence for.
- `databaseReference` - A `DatabaseReference` object representing the path to store presence data.
- `onError` - The widget to be displayed when receiving data from the RTDB.
- `builder` - The widget to show when data is received from the RTDB.

## `FirebasePresenceWidgetState` (enum)

Represents the various lifecycle states of a `FirebasePresence` widget.

- `init` - Indicates that the widget has initialised its data.
- `inactive` - Indicates an inactive lifecycle state for this widget.
- `paused` - Indicates a paused lifecycle state for this widget.
- `resumed` - Indicates a resumed lifecycle state for this widget.
- `detached` - Indicates a detached lifecycle state for this widget.
- `error` - Indicates an error occured when sending or receiving data to/from the RTDB.
- `Null` - Indicates that the data received from the RTDB was null.

## Cloud Firestore / Cloud function to reflect presence data

Additionally, we can utilise a cloud function to have presence data across to Cloud Firestore.

**Example**
```javascript
// Presence
exports.onUserStatusChange = functions.database

  // The database reference should match that of what was specified
  // on the `FirebasePresence` widget.
  .ref("/presence/{uid}")
  .onUpdate(async (change, context) => {
    // Get the data written to Realtime Database
    const data = change.after.val();

    // Get a reference to the Firestore document
    const userAccountStatusRef = firestore.doc(`users/${context.params.uid}`);

    // Update the values on Firestore
    console.log();
    return userAccountStatusRef.set({
      account: {presence: data},
    });
  });
```

## Reaching out

Contributions, issues and feature requests are welcome.

- [Issues](https://github.com/flutterfocus/firebase_presence/issues)
- [Pull requests](https://github.com/flutterfocus/firebase_presence/pulls)

## Author - Paurini Wiringi
This project is created with love.

Liked some of [my](https://github.com/flutterfocus) work or found it useful? Sponsors are welcome!

<a href="https://github.com/sponsors/flutterfocus" target="_blank"><img src="https://t3.ftcdn.net/jpg/04/07/88/00/360_F_407880054_fdbzTfwmIBaDmb84pg4hDJ3rb1ezRpZw.jpg" alt="Support me" style="height: 20% !important;width: 20% !important;" ></a>

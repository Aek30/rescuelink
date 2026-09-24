# Phase 3 — SOS / Rescue / Location

## Implemented

- SOS form: requester name, emergency category, people count, details, optional foreground GPS with accuracy and fix timestamp.
- Explicit recipient selection from known peers and confirmation of the information to be sent. No automatic location broadcast to newly discovered peers.
- Active incidents keep their selected recipients until cancellation. A new incident can use different recipients.
- SOS create/update/cancel and recipient outbox rows persist atomically in existing SQLite settings/messages tables. Phase 2 data requires no destructive migration.
- Direct Nearby delivery, stable retry IDs, ACK after storage, duplicate protection, and revision ordering. Superseded outgoing revisions stay in history but are not retried.
- Rescue Mode lists latest incident states, including cancellations, timestamps, offline state, coordinates and a route to the sender's chat. Mode persists across restarts. SOS reception also works while Rescue Mode is off.
- Incident ID, payload version and revision provide a basis for later relay work; no multi-hop transport yet.

## Physical test result — 2026-09-25

The user reported that all five guided test sections passed on physical Android phones: offline connection, SOS without coordinates, GPS update and reply chat, offline persistence/reconnect/cancellation, and GPS unavailable/permission-denied handling. This is a user-reported result, not an automated or agent-observed run. Phone models, Android versions and exact APK identifier were not supplied. The extended scenarios below (including a third phone and packet reordering) were not individually reported.

## Extended physical acceptance checklist

Install the same Phase 3 APK on two Android phones. Keep Wi-Fi radio and Bluetooth enabled; disconnect internet Wi-Fi and disable mobile data. Connect A and B from the home screen before selecting SOS recipients. Keep both apps in the foreground.

1. A opens SOS, enters Thai text, category and people, selects B and sends without GPS. Verify B's Rescue Mode displays the information and A shows recipient storage confirmation. Open chat from B's request card and reply; verify both histories.
2. A taps GPS, grants permission, and checks coordinates, accuracy and fix time before confirming an update. Verify B receives exactly those coordinates. GPS can take longer without internet; the app times out after 25 seconds and still allows sending without coordinates.
3. Test denied/permanently denied permission, Location service off, approximate location and no GPS fix. Confirm error feedback and ability to remove coordinates/send without them. On Android 13+ Nearby should remain usable without granting SOS location permission.
4. Update details/GPS, then cancel. Verify B shows the latest update followed by cancellation. Recipient storage confirmation is not rescue acceptance.
5. Disconnect; create/update/cancel while offline, force-close/reopen A, reconnect and wait at least 10 seconds. Verify persisted state and latest cancellation arrives; old active revisions do not reactivate the incident.
6. Lose the connection during send/ACK. Reconnect and verify retries do not create duplicate incident cards. Restart B and verify SOS inbox and Rescue Mode preference persist.
7. Cancel and create another incident before reconnecting. Verify the previous cancellation and new incident both arrive correctly.
8. With C also connected, select only B. Verify C receives no SOS/location. Cancel before changing recipients to C.
9. Run the Phase 2 text/history checklist to verify existing chat behavior and installation data survive an APK upgrade without clearing data.
10. Background either app, resume and reconnect manually. Verify queued data is retained; do not expect background delivery or notifications.

Record device model, Android version, APK build, actual result and failures. Fake-transport tests cannot establish GPS or radio behavior on phones.

## Limitations

No cloud, maps, media, background notification, automatic rescuer assignment or authenticated rescue identities. Nearby auto-accept remains the existing POC behavior. GPS is a snapshot, not live tracking; recipients see capture time and accuracy. Phase 2 peers do not process or ACK SOS. Updating location requires tapping GPS and confirming an update.

Implementation references: [location API](https://pub.dev/documentation/location/latest/), [Android location permissions](https://developer.android.com/develop/sensors-and-location/location/permissions/runtime).

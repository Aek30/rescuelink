# Phase 2: Reliable Offline Messaging

## Implemented

- SQLite stores installation UUID, known peers and messages before transmission.
- JSON message/deviceInfo/ACK protocol over the existing Nearby byte transport.
- PENDING = saved locally; SENT = accepted by transport; DELIVERED = recipient saved and ACK received. This is not a read receipt.
- Known-peer conversations, message bubbles, local date/time and delivery status.
- Pending and sent messages retry every 5 seconds while connected, with the same ID. Duplicate reception re-sends ACK without a second row.
- Reconnection exchanges stable installation IDs; transient Nearby endpoint IDs are not conversation IDs.
- Existing advertising, discovery, auto-accept and foreground-only lifecycle remain in place.

## Physical A ↔ B acceptance checklist (not yet verified)

Install the same Phase 2 APK on both Android phones. Keep Bluetooth, Wi-Fi radio and Location on; disconnect internet Wi-Fi and turn mobile data off.

1. A starts Advertising; B starts Discovery and connects. Both should display the other under Conversations after identity exchange.
2. Tap the conversation and send English, Thai and emoji both ways. Verify the receiver's text and sender's DELIVERED status.
3. STOP, open the saved conversation, send while offline. Verify PENDING and retention after force-closing and reopening the app.
4. Reconnect. Verify queued text arrives once and advances to DELIVERED. Verify old history belongs to the same conversation even if the device name/endpoint changes.
5. Break the connection immediately after sending. Reconnect and wait at least 10 seconds. Verify the message appears once and eventually becomes DELIVERED.
6. Restart both apps. Verify received and sent history and statuses remain. Reconnect and send again.
7. Send blank/whitespace and a message larger than 32 KB including JSON overhead; verify an error and no invalid queued row.
8. Deny permissions, then restore them; confirm Phase 1 discovery/connect behavior still works.
9. If available, connect a third phone and verify messages/ACKs stay within the selected conversation.

Record phone models, Android versions, APK build, actual results and failures. Automated tests cannot confirm radio behavior on physical phones.

## Scope

Both phones require Phase 2; legacy plain-text packets are not imported. No relay, background delivery, cloud sync or SOS processing yet. Reconnect manually after returning from background. Installation identity and history survive app restarts, but not clearing app data or uninstalling. Auto-accept remains a test-only feature; peer IDs are not authenticated identities. Names may change after restart; conversation identity does not.

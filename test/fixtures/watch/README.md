Example messages between the phone and the watch app. Both sides are tested
against these, so a change to one side that the other can't read fails a test.

- `context.json`: phone to watch (`WatchProtocol.context` in
  lib/services/watch_protocol.dart, read by `PhoneContext` in
  ios/TimestampWatch/PhoneProtocol.swift). `accuracy` is the phone's last
  time server sync, null until it has one; the watch's events get its
  precision. `referenceSetAt` is when the reference was last chosen, on
  either side; null if never.
- `changes.json`: watch to phone (`WatchChanges` in PhoneProtocol.swift, read
  by `WatchChanges.parse` in watch_protocol.dart). `reference`, when there,
  is a reference the watch chose and when; the later of the phone's and the
  watch's choices wins.

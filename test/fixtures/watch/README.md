Example messages between the phone and the watch app. Both sides are tested
against these, so a change to one side that the other can't read fails a test.

- `context.json`: phone to watch (`WatchProtocol.context` in
  lib/services/watch_protocol.dart, read by `PhoneContext` in
  ios/TimestampWatch/PhoneProtocol.swift).
- `changes.json`: watch to phone (`WatchChanges` in PhoneProtocol.swift, read
  by `WatchChanges.parse` in watch_protocol.dart).

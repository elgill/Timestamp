# AGENTS.md

Notes for coding agents (and people) working on this repo.

## Project

Flutter app **Timestamp** (`dev.gillin.timestamp`) with a companion Apple Watch app
(`dev.gillin.timestamp.watchkitapp`). The iOS project is in `ios/`. Open
`ios/Runner.xcworkspace`, not the `.xcodeproj`.

- Apple Developer team: `CPAZW3J38G`. All targets use automatic signing.
- Version and build number come from `version:` in `pubspec.yaml` (`<version>+<build>`).

## Releasing to App Store Connect from the CLI

### One-time setup per machine

1. **Xcode:** install the current Xcode and point the command-line tools at it:
   ```sh
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   xcode-select -p   # should print /Applications/Xcode.app/Contents/Developer
   ```
   If `xcode-select` points to an older Xcode or a beta, `flutter build` fails with
   *"There are no accounts registered with Xcode"* and *"No profiles for ... were
   found"*, even when Xcode itself is signed in.
2. **Apple ID:** in Xcode → Settings → Accounts, sign in with the account that belongs
   to team `CPAZW3J38G`. Then build once from Xcode (Product → Build, with a device
   selected) so the development profiles for both Runner and watchkitapp get created.
3. **App Store Connect API key (per machine).** Each machine can use its own key,
   which lets you revoke one machine's access on its own.
   - Create a key in App Store Connect → Users and Access → Integrations →
     App Store Connect API (App Manager role), or reuse one you already have.
     Apple only lets you download the `.p8` file once.
   - Save it as `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`.
     **Never commit the `.p8` file.** `.gitignore` excludes `*.p8`.
   - Create `.asc.env` in the repo root. It is git-ignored and stays on this machine:
     ```sh
     ASC_KEY_ID=<Key ID shown next to the key in App Store Connect>
     ASC_ISSUER_ID=<Issuer ID shown above the key list; the same for every key on the team>
     ```

   **Agents:** before uploading, check that `.asc.env` exists and that
   `~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8` is there. If either is
   missing, walk the user through the steps above, ask for the Key ID and
   Issuer ID, and write `.asc.env` for them. Don't ask them to paste the `.p8`
   contents into the chat.

### Each release

1. Raise the build number in `pubspec.yaml` (e.g. `1.2.0+40` → `1.2.0+41`).
   App Store Connect rejects a build number that has already been uploaded.
2. Build and archive:
   ```sh
   flutter build ipa --release
   ```
   Output: `build/ios/ipa/timestamp.ipa` (includes the watch app).
3. Upload:
   ```sh
   set -a; source .asc.env; set +a
   xcrun altool --upload-app --type ios \
     -f build/ios/ipa/timestamp.ipa \
     --apiKey "$ASC_KEY_ID" \
     --apiIssuer "$ASC_ISSUER_ID"
   ```
   A successful upload ends with `UPLOAD SUCCEEDED`. You can ignore the
   `ERROR ... CDUploaderStateInfoResumeFilePath ... doesn't exist` line it may
   print before that.
4. Apple processes the build, usually within 5–30 minutes. It then shows up under
   TestFlight in App Store Connect, and Apple emails you if processing fails.

### Notes for agents

- Run the signing, build and upload commands outside any sandbox. A sandboxed shell
  can't reach the Xcode account or keychain, which causes the same
  "no accounts registered" error.
- Ask the user before uploading. An upload publishes a build and uses up that
  build number.

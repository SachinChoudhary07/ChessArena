# Secrets rotation checklist (do before the first Play Store upload)

This repository is **public**, and these files were committed in the past, so
treat every one of them as leaked. Removing them from the current code does
not remove them from git history; rotating them is what makes the leak harmless.

## 1. Firebase Admin service-account key (most urgent)

`lib/Firebase/serverKey.json` was a full Admin SDK key for the project's
`firebase-adminsdk-…` service account. Anyone with it can read and write all
of Firestore, Realtime Database, Storage and Auth, bypassing security rules.

1. Google Cloud Console → IAM & Admin → Service accounts → your Firebase
   project → the `firebase-adminsdk-…` account → **Keys**.
2. Delete the key that was committed (its id is the `private_key_id` in your
   local copy of serverKey.json). Delete any other keys you don't recognise.
3. Do **not** create a replacement key for the app. Push notifications are now
   sent by the `notifyOnChallengeCreated` Cloud Function, which uses the
   project's built-in credentials.

## 2. Deploy the Cloud Function

Cloud Functions need the Firebase **Blaze** (pay-as-you-go) plan; this usage
fits well inside the free tier.

```
npm install -g firebase-tools
firebase login
cd functions && npm install && cd ..
firebase deploy --only functions,firestore:rules
```

The new Firestore rule only lets a user create a challenge where
`challenger` is their own uid, so nobody can send notifications as someone else.

## 3. google-services.json / Firebase API key

The Android API key in `google-services.json` is not a secret by design, but
since it is public:

1. Google Cloud Console → APIs & Services → Credentials → the Android key.
2. Restrict it to **Android apps** with your package name and the SHA-1
   fingerprints of your new upload key and of the Play App Signing key.
3. Turn on Firebase **App Check** enforcement (the app already includes
   `firebase_app_check`).
4. Download a fresh `google-services.json` from the Firebase console into
   `android/app/` locally. It is git-ignored and must stay that way.

## 4. Upload keystore

`android/app/my-release-key.jks` and the password once written in
`build.gradle` are public. Never use that keystore to sign a Play release.

- If this app was **never** uploaded to Google Play: create a new keystore and
  use it as the upload key when you create the app (Play App Signing is on by
  default):

  ```
  keytool -genkey -v -keystore ~/chessarena-upload.jks -keyalg RSA \
    -keysize 2048 -validity 10000 -alias upload
  ```

  Then create `android/key.properties` (git-ignored) with `storePassword`,
  `keyPassword`, `keyAlias=upload` and `storeFile=<absolute path to the .jks>`.

- If a build signed with the old key **was** uploaded to Play: in Play Console →
  Setup → App integrity, request an **upload key reset** with a new keystore.

Back up the new keystore and passwords outside the repo (a password manager).
Add its SHA-1 (`keytool -list -v -keystore …`) to the Firebase Android app
settings, or Google Sign-In will stop working.

## 5. Optional: scrub git history

Once the keys above are rotated, the old files in history are useless to an
attacker. Scrubbing history (`git filter-repo`) needs a force-push and breaks
existing clones, so it is optional.

# Consistency (working name)

A free habit and to-do app for students, plus a small website.

- **App** (`app/`): Flutter, Android first. Tasks with alarms, habit trackers, streaks with "never miss twice", weekly goals, a "bad day" version of every habit, 7-day bars, a 16-week calendar, insights, story-sized share cards, optional public link.
- **Website** (`web/`): landing page with a playable streak demo, and the public streak page that Instagram-bio links open. Static files, hosted on Firebase Hosting.
- **Storage**: everything lives on the phone. Firebase is used only for the optional public link.

## Status: what is verified and what is not

| Part | State |
| --- | --- |
| Website (landing, public profile, states, mobile, dark mode) | Tested in a real browser: desktop and phone widths, XSS attempt, not-found and not-configured pages |
| Streak rule | Tested in JavaScript (`node web/test/streak.test.js`) |
| Flutter app | **Written but not compiled yet.** Flutter could not be installed in the environment it was written in. Expect to fix a few small errors on first build (see "First build" below) |
| Dart tests (`app/test/streak_test.dart`) | Written, not run. They mirror the JavaScript tests |

## Folder map

```
app/
  pubspec.yaml
  lib/
    main.dart             start-up
    config.dart           app name + your website URL  <- edit
    models.dart           Habit, Task, dates
    store.dart            all data, streak logic, insights
    notifications.dart    alarms (next 14 days, re-planned on every open)
    cloud.dart            optional Firebase public link
    theme.dart
    screens/              today, habits, insights, editors, detail, share card, profile
    widgets/              heatmap, week bars, quick-log sheet
  test/streak_test.dart
web/
  firebase.json           hosting + /u/** rewrite
  firestore.rules         who can read/write public pages
  public/
    index.html, profile.html
    css/site.css
    js/config.js          <- edit (Firebase project id + API key, app link)
    js/streak.js, home.js, profile.js
  test/streak.test.js
```

## 1. First build of the app

You need Flutter installed (https://docs.flutter.dev/get-started/install).

```bash
cd app
flutter create . --platforms=android,ios --org com.yourname --project-name consistency
```

`flutter create .` adds the `android/` and `ios/` folders and should leave `lib/` and `pubspec.yaml` alone. If it replaced `lib/main.dart`, copy yours back.

```bash
flutter pub get
flutter analyze        # fix anything it reports (see below)
flutter test           # runs the streak tests
flutter run            # with an Android phone or emulator connected
```

Likely first-build fixes, because the code was never compiled:
- `flutter analyze` may point at small type or import mistakes. They are one-line fixes.
- Plugin versions move quickly. If `flutter pub get` complains, run `flutter pub upgrade --major-versions`. The two plugins most likely to need code changes are `flutter_local_notifications` (alarm scheduling call in `notifications.dart`) and `share_plus` (share call in `share_card_screen.dart` and `profile_screen.dart`). Their changelogs show the new call shape.

### Android settings for alarms

Open `android/app/src/main/AndroidManifest.xml`.

Inside `<manifest>` (above `<application>`):

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

Inside `<application>`:

```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
    <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
  </intent-filter>
</receiver>
```

In `android/app/build.gradle` (or `build.gradle.kts`) turn on desugaring, which the notifications plugin needs:

```gradle
android {
    compileOptions { coreLibraryDesugaringEnabled true }
}
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
```

Check the plugin's README (https://pub.dev/packages/flutter_local_notifications) for the exact current text, since it changes between versions.

The app asks for notification permission the first time someone turns an alarm on, not at install.

## 2. Website

The site works before Firebase: the landing page and `/u/demo` (a sample streak page) need nothing.

```bash
# preview locally, any static server works:
cd web/public && python3 -m http.server 5000
# note: /u/<name> pages need Firebase's rewrite, so test those after deploying
```

## 3. Firebase (only needed for public links)

1. Create a project at https://console.firebase.google.com.
2. **Authentication** -> Sign-in method -> turn on **Anonymous**.
3. **Firestore Database** -> Create database (production mode).
4. **Project settings** -> Your apps -> add a **Web app**. Copy `projectId` and `apiKey` into `web/public/js/config.js`.
5. Deploy the site and the rules:
   ```bash
   npm install -g firebase-tools
   firebase login
   cd web
   firebase use --add          # pick your project
   firebase deploy             # hosting + firestore rules
   ```
6. Connect the app:
   ```bash
   dart pub global activate flutterfire_cli
   cd app
   flutterfire configure       # pick the same project, Android (and iOS)
   ```
7. In `app/lib/config.dart` set `kShareBaseUrl` to your site address (for example `https://your-project.web.app`).

Then in the app: Today -> profile icon -> **Create public link**. The link looks like `https://your-project.web.app/u/k3x9...`.

What the public page contains: display name, habit names, streaks, and the days logged. No location, no task titles. The Firestore rules let anyone read one page if they have the link, let nobody list or search pages, and let only the creator change or delete their own.

Known limit: the creator is an anonymous account tied to the phone. If someone clears the app's data or switches phones, they can no longer update that page and would create a new one. Adding Google sign-in later fixes this.

## 4. Before you publish to the Play Store

- Pick the real name and replace "Consistency" in `config.dart`, `index.html`, and `profile.html`.
- Write a privacy policy page (required by Play). Say that data stays on the device and what the optional public page contains.
- Add an app icon (`flutter_launcher_icons`).
- Test alarms on a few real phones. Some brands (Xiaomi, Oppo, Vivo, Realme) kill background alarms unless battery optimisation is turned off for the app.

## 5. What comes next (from the plan)

Version 1 (this repo) is the core loop. In rough order after it:

1. GPS run and walk tracking with distance, pace and steps (Android first). Needs background location, so show a clear explanation screen and ask for the permission only when the user sets up their first place.
2. "Are you at the gym?" prompts using geofencing around a saved place, with an option to log automatically after a few confirmations.
3. Friends and one accountability buddy, then college challenges.
4. Privacy zone for routes before sharing (hide the first and last few hundred metres).
5. Regional languages, widgets, spaced-revision reminders for study.
6. Google sign-in so public pages and data follow the user across phones.

Known simplifications in v1: alarms are planned 14 days ahead, so open the app at least every couple of weeks (iOS holds only 64 pending notifications); there is no "mark done" button inside the notification yet; dark mode follows the phone.

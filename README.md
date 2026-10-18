# SE Exam Study Tracker

A Flutter app for tracking how much time I study for the SE Exam.

## Milestones

- [x] **1. Timer + daily recording.** Start/stop timer, survives the app being closed, splits sessions at midnight, saved on the phone.
- [ ] **2. Bottom tabs + calendar view.** Daily totals on a calendar; tap a day to see, add or edit sessions.
- [ ] **3. Stats tab.** Cumulative and weekly totals, with a chart toggled daily / weekly / monthly.
- [ ] **4. Averages.** Weekday, weekend (Sat + Sun), and all-days averages.
- [ ] **5. Firebase.** Email + Google login, profile icon, cloud sync.

## First-time setup

The repo holds the app code (`lib/`) and `pubspec.yaml`. Generate the Android/iOS folders once after cloning:

```
git clone https://github.com/cchigu/se-study-tracker.git
cd se-study-tracker
flutter create . --project-name se_study_tracker --platforms android,ios
flutter pub get
flutter run
```

`flutter create .` only adds the missing platform files; it doesn't touch `lib/`. Commit the generated `android/` and `ios/` folders afterwards so you only do this once.

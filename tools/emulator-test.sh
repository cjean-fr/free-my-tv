#!/usr/bin/env bash
# Runs on the emulator-runner's emulator: installs the APK, makes Free My TV the home screen the way the in-app
# switch does (adb's set-home-activity, see HomeMode), walks Settings > Inputs and saves screenshots.
set -uo pipefail
mkdir -p emulator-shots
adb wait-for-device
adb shell input keyevent KEYCODE_WAKEUP
sleep 2
adb shell settings put system screen_off_timeout 1800000 || true
# Skip the first-boot setup wizard so HOME reaches the home screen.
adb shell settings put global device_provisioned 1 || true
adb shell settings put secure user_setup_complete 1 || true
adb shell settings put secure tv_user_setup_complete 1 || true

adb install -r FreeMyTV.apk || { echo "install failed"; exit 1; }
# What the TV lists: evidence for which inputs the editor can show.
adb shell dumpsys tv_input > emulator-shots/tv-inputs.txt 2>&1 || true

# Take the HOME role from the setup wizard, then make Free My TV the home screen like the in-app switch does.
adb shell cmd role get-role-holders --user 0 android.app.role.HOME > emulator-shots/home-role.txt 2>&1 || true
CUR=$(adb shell cmd role get-role-holders --user 0 android.app.role.HOME | tr -d '\r' | tail -1)
[ -n "$CUR" ] && adb shell cmd role remove-role-holder --user 0 android.app.role.HOME "$CUR" >> emulator-shots/home-role.txt 2>&1 || true
adb shell cmd role add-role-holder --user 0 android.app.role.HOME io.freemytv >> emulator-shots/home-role.txt 2>&1 || true
adb shell cmd package set-home-activity io.freemytv/.HomeActivity >> emulator-shots/home-role.txt 2>&1 || true
adb shell input keyevent KEYCODE_HOME
sleep 8
adb exec-out screencap -p > emulator-shots/1-home.png

# Settings > Inputs (6th row of the main settings list).
adb shell am start -n io.freemytv/.SettingsActivity
sleep 5
for i in 1 2 3 4 5; do adb shell input keyevent DPAD_DOWN; sleep 1; done
adb shell input keyevent DPAD_CENTER
sleep 3
adb exec-out screencap -p > emulator-shots/2-inputs-editor.png

# Hide the second entry, then move the first one place down, as the editor's keys do.
adb shell input keyevent DPAD_DOWN; sleep 1
adb shell input keyevent DPAD_CENTER; sleep 1
adb shell input keyevent DPAD_UP; sleep 1
adb shell input keyevent DPAD_RIGHT; sleep 1
adb exec-out screencap -p > emulator-shots/3-inputs-edited.png

# Back to home: the drawer should follow the chosen order and visibility.
adb shell input keyevent BACK; sleep 2
adb shell input keyevent BACK; sleep 2
adb shell input keyevent KEYCODE_HOME; sleep 5
adb shell input keyevent DPAD_LEFT; sleep 2
adb exec-out screencap -p > emulator-shots/4-home-after.png
adb shell dumpsys tv_input > emulator-shots/tv-inputs-after.txt 2>&1 || true
exit 0

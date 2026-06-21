#!/bin/zsh
# Sources the environment variables Skip + the Android toolchain need.
# Usage:  source Tools/android-env.sh
#
# After sourcing, `skip checkup`, `gradle`, `adb`, `sdkmanager`, `avdmanager`
# and `emulator` all work in the current shell.

export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/emulator:$PATH"

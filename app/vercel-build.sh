#!/usr/bin/env bash
set -e
if cd flutter; then git pull && cd ..; else git clone https://github.com/flutter/flutter.git -b stable; fi
flutter/bin/flutter doctor
flutter/bin/flutter config --enable-web
flutter/bin/flutter pub get
flutter/bin/flutter build web --release --dart-define=API_BASE=$API_BASE --dart-define=RAZORPAY_KEY_ID=$RAZORPAY_KEY_ID

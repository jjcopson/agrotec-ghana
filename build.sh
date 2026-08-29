#!/bin/bash
set -e
curl -sL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.32.2-stable.tar.xz -o /tmp/flutter.tar.xz
tar xf /tmp/flutter.tar.xz -C /tmp
git config --global --add safe.directory /tmp/flutter
git config --global --add safe.directory '*'
export FLUTTER_ROOT=/tmp/flutter
/tmp/flutter/bin/flutter config --no-analytics --enable-web
/tmp/flutter/bin/flutter pub get
/tmp/flutter/bin/flutter build web --release --base-href /

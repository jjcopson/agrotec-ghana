#!/bin/bash
set -e
curl -sL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.32.2-stable.tar.xz -o /tmp/flutter.tar.xz
tar xf /tmp/flutter.tar.xz -C /tmp
/tmp/flutter/bin/flutter config --no-analytics --enable-web
/tmp/flutter/bin/flutter pub get
/tmp/flutter/bin/flutter build web --release --base-href /

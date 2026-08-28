#!/bin/bash
set -e
wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.32.2-stable.tar.xz -O /tmp/flutter.tar.xz
tar xf /tmp/flutter.tar.xz -C $HOME
export PATH=$PATH:$HOME/flutter/bin
flutter config --no-analytics --enable-web
flutter pub get
flutter build web --release --base-href /

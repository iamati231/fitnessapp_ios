#!/bin/bash
# Setzt CURRENT_PROJECT_VERSION auf git commit count und generiert das Xcode-Projekt.
# Aufruf in Appcircle Custom Script: bash .scripts/ci-xcodegen.sh
set -euo pipefail

BUILD_NUM=$(git rev-list --count HEAD)
echo "Build number: $BUILD_NUM"
sed -i "s/CURRENT_PROJECT_VERSION: '[0-9]*'/CURRENT_PROJECT_VERSION: '${BUILD_NUM}'/" project.yml
xcodegen generate

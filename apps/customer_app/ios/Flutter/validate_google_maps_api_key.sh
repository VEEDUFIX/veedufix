#!/bin/sh
set -eu

case "${CONFIGURATION:-}" in
  Release|Profile)
    case "${GOOGLE_MAPS_API_KEY:-}" in
      ""|'$(GOOGLE_MAPS_API_KEY)'|REPLACE_WITH_*)
        echo "error: Set GOOGLE_MAPS_API_KEY in ios/Flutter/Secrets.xcconfig before building $CONFIGURATION." >&2
        exit 1
        ;;
    esac
    ;;
esac

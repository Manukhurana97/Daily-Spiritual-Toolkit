#!/bin/bash
> log.txt

SECRETS="config/secrets.json"
DART_DEFINE_FLAG=""
if [ -f "$SECRETS" ]; then
  DART_DEFINE_FLAG="--dart-define-from-file=$SECRETS"
fi

{
  flutter clean
  flutter pub get
  flutter run "$@"
  flutter run $DART_DEFINE_FLAG "$@"
} 2>&1 | tee log.txt
#!/bin/bash
> log.txt
{
  flutter clean
  flutter pub get
  flutter run "$@"
} 2>&1 | tee log.txt
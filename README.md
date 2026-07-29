# Hangul Blitz

Hangul Blitz is a SwiftUI iOS app for building fast, direct Hangul reading skills without relying on romanisation.

## Current status

The app currently contains the initial iPhone and iPad navigation experience, reusable UI components, English and Simplified Chinese localisations, and mock course/progress data for interface development.

Production course data and audio assets are still being prepared. They intentionally live outside this repository and have not yet been integrated into the app target.

## Requirements

- Xcode with the iOS 26.1 SDK
- An iPhone or iPad simulator running iOS 26.1 or later

## Run locally

1. Open `hangulblitz.xcodeproj` in Xcode.
2. Select the `hangulblitz` scheme.
3. Choose an iPhone or iPad simulator.
4. Build and run the app.

## Project structure

```text
hangulblitz/
├── Components/       Reusable SwiftUI components
├── Model/            Navigation, course, and progress models
├── View/             App screens and responsive layouts
├── Assets.xcassets/  App icons, branding, and colours
├── Localizable.xcstrings
├── ContentView.swift
└── hangulblitzApp.swift
```

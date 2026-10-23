// Where the app talks to. Owner: Hiba.
// Fill these once (or pass them at build time with --dart-define=NAME=value):
//   flutter build apk --release --dart-define=MITRA_SITE=https://<site>.netlify.app
//     --dart-define=FIREBASE_PROJECT=<project-id> --dart-define=FIREBASE_API_KEY=<web api key>
// The Firebase values are the same public web config pasted into js/data.js (projectId, apiKey).
// While they are empty, the app keeps everything on the phone and works offline, as before.
import 'package:flutter/foundation.dart';

/// Netlify site that hosts the call-me function.
const _site = String.fromEnvironment('MITRA_SITE');

/// Firestore project (Firebase console → Project settings → General → Project ID).
const firebaseProject = String.fromEnvironment('FIREBASE_PROJECT');

/// Firebase web API key (same page, "Web API key"). Public by design; Firestore rules control access.
const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');

/// The site to call. The web build served from Netlify uses its own address.
String get siteUrl {
  if (_site.isNotEmpty) return _site.endsWith('/') ? _site.substring(0, _site.length - 1) : _site;
  if (kIsWeb && Uri.base.scheme.startsWith('http') && !Uri.base.host.contains('localhost')) return Uri.base.origin;
  return '';
}

bool get cloudConfigured => firebaseProject.isNotEmpty;

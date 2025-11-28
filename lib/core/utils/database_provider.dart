import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// 🎯 TODO: Run the flutterfire configure command for your guest project
// and import the generated file here.
// import 'package:nutricare_connect/firebase_options_guest.dart';

// 1. THE SWITCH: False = Live (Default), True = Guest
final isGuestModeProvider = StateProvider<bool>((ref) => false);

// 2. THE DATABASE FACTORY (Initializes the correct App)
final firebaseAppProvider = FutureProvider<FirebaseApp>((ref) async {
  final isGuest = ref.watch(isGuestModeProvider);

  if (isGuest) {
    // Try to get the existing 'guest' app instance
    try {
      return Firebase.app('guest');
    } catch (e) {
      // If not initialized, initialize it now.
      // 🎯 UNCOMMENT THIS BLOCK AFTER GENERATING firebase_options_guest.dart
      /*
      return await Firebase.initializeApp(
        name: 'guest',
        options: DefaultFirebaseOptionsGuest.currentPlatform,
      );
      */

      throw Exception(
          "Guest Config Missing! You must generate firebase_options_guest.dart first."
      );
    }
  } else {
    // Return default 'live' app (uses google-services.json)
    return Firebase.app();
  }
});

// 3. THE INJECTORS (Services will use these instead of .instance)

// Provides the correct Firestore instance (Live or Guest)
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  final isGuest = ref.watch(isGuestModeProvider);

  if (isGuest) {
    try {
      return FirebaseFirestore.instanceFor(app: Firebase.app('guest'));
    } catch (e) {
      throw Exception("Guest App not initialized. Call firebaseAppProvider first.");
    }
  }
  return FirebaseFirestore.instance;
});

// Provides the correct Auth instance (Live or Guest)
final authProvider = Provider<FirebaseAuth>((ref) {
  final isGuest = ref.watch(isGuestModeProvider);

  if (isGuest) {
    try {
      return FirebaseAuth.instanceFor(app: Firebase.app('guest'));
    } catch (e) {
      throw Exception("Guest App not initialized. Call firebaseAppProvider first.");
    }
  }
  return FirebaseAuth.instance;
});
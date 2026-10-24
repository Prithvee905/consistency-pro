import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Optional cloud features. Everything in the app works offline; this is only
/// used when the user taps "Create public link" to share a streak page.
///
/// Until Firebase is configured (see README), [ready] stays false and the
/// profile screen explains that instead of crashing.
class CloudService {
  bool ready = false;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      ready = true;
    } catch (e) {
      debugPrint('Firebase not configured yet: $e');
      ready = false;
    }
  }

  Future<String> _uid() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
    if (user == null) throw StateError('Could not sign in.');
    return user.uid;
  }

  Future<void> publish(String slug, Map<String, dynamic> profile) async {
    if (!ready) {
      throw StateError('Cloud is not set up yet. Follow the Firebase steps in the README.');
    }
    final uid = await _uid();
    await FirebaseFirestore.instance.collection('profiles').doc(slug).set({
      ...profile,
      'owner': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unpublish(String slug) async {
    if (!ready) return;
    await _uid();
    await FirebaseFirestore.instance.collection('profiles').doc(slug).delete();
  }
}

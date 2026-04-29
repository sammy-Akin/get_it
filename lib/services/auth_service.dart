import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String role = 'customer',
    String? businessName,
    String? location,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(fullName);
      await _saveUserToFirestore(
        uid: credential.user!.uid,
        fullName: fullName,
        email: email,
        photoUrl: credential.user?.photoURL,
        role: role,
        businessName: businessName,
        location: location,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      try {
        await _ensureUserDoc(
          uid: credential.user!.uid,
          fullName: credential.user?.displayName ?? '',
          email: credential.user?.email ?? '',
          photoUrl: credential.user?.photoURL,
        );
      } catch (_) {
        // Firestore errors should not block login
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      late UserCredential userCredential;

      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Step 1: Authenticate — shows the Google account picker
        final GoogleSignInAccount googleUser = await GoogleSignIn.instance
            .authenticate();

        // Step 2: Get client authorization (access token) for the required scopes.
        // Try silently first; fall back to interactive if not yet authorized.
        final authorization =
            await googleUser.authorizationClient.authorizationForScopes([
              'email',
              'profile',
            ]) ??
            await googleUser.authorizationClient.authorizeScopes([
              'email',
              'profile',
            ]);

        // Step 3: Build the Firebase credential using the access token
        final oauthCredential = GoogleAuthProvider.credential(
          accessToken: authorization.accessToken,
        );

        userCredential = await _auth.signInWithCredential(oauthCredential);
      }

      await _saveUserToFirestore(
        uid: userCredential.user!.uid,
        fullName: userCredential.user?.displayName ?? '',
        email: userCredential.user?.email ?? '',
        photoUrl: userCredential.user?.photoURL,
        role: 'customer',
      );

      return userCredential;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw 'Google Sign-In failed: ${e.description}';
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> signOut() async {
    try {
      // signOut (not disconnect) ends the session without revoking access,
      // allowing users to sign back in smoothly.
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  Future<String> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('getit_users').doc(uid).get();
      return (doc.data()?['role'] as String?) ?? 'customer';
    } catch (_) {
      return 'customer';
    }
  }

  Future<void> _saveUserToFirestore({
    required String uid,
    required String fullName,
    required String email,
    String? photoUrl,
    String role = 'customer',
    String? businessName,
    String? location,
  }) async {
    final userRef = _firestore.collection('getit_users').doc(uid);
    final userDoc = await userRef.get();

    if (!userDoc.exists) {
      final data = <String, dynamic>{
        'uid': uid,
        'fullName': fullName,
        'email': email,
        'photoUrl': photoUrl ?? '',
        'role': role,
        'addresses': [],
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (businessName != null && businessName.isNotEmpty) {
        data['shopName'] = businessName;
      }
      if (location != null && location.isNotEmpty) {
        data['location'] = location;
      }

      await userRef.set(data);

      if (role == 'vendor') {
        await _firestore.collection('getit_vendors').doc(uid).set({
          'id': uid,
          'name': businessName ?? fullName,
          'ownerName': fullName,
          'email': email,
          'location': location ?? '',
          'category': '',
          'description': '',
          'imageUrl': '',
          'isOpen': true,
          'isApproved': true,
          'rating': 5.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (role == 'picker') {
        await _firestore.collection('getit_riders').doc(uid).set({
          'id': uid,
          'name': fullName,
          'email': email,
          'location': location ?? '',
          'isAvailable': true,
          'totalDeliveries': 0,
          'totalEarnings': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } else {
      await userRef.update({
        'fullName': fullName,
        'email': email,
        'photoUrl': photoUrl ?? '',
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _ensureUserDoc({
    required String uid,
    required String fullName,
    required String email,
    String? photoUrl,
  }) async {
    final userRef = _firestore.collection('getit_users').doc(uid);
    final userDoc = await userRef.get();
    if (!userDoc.exists) {
      await userRef.set({
        'uid': uid,
        'fullName': fullName,
        'email': email,
        'photoUrl': photoUrl ?? '',
        'role': 'customer',
        'addresses': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await userRef.update({'lastSeen': FieldValue.serverTimestamp()});
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}

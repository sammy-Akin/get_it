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

      // Ensure Firestore doc exists — handles orphaned accounts
      await _ensureUserDoc(
        uid: credential.user!.uid,
        fullName: credential.user?.displayName ?? '',
        email: credential.user?.email ?? '',
        photoUrl: credential.user?.photoURL,
      );

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleProvider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');

      late UserCredential userCredential;

      if (kIsWeb) {
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        userCredential = await _auth.signInWithProvider(googleProvider);
      }

      await _saveUserToFirestore(
        uid: userCredential.user!.uid,
        fullName: userCredential.user?.displayName ?? '',
        email: userCredential.user?.email ?? '',
        photoUrl: userCredential.user?.photoURL,
        role: 'customer',
      );

      return userCredential;
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

  // Full save — only writes role on first creation
  Future<void> _saveUserToFirestore({
    required String uid,
    required String fullName,
    required String email,
    String? photoUrl,
    String role = 'customer',
  }) async {
    final userRef = _firestore.collection('getit_users').doc(uid);
    final userDoc = await userRef.get();
    if (!userDoc.exists) {
      await userRef.set({
        'uid': uid,
        'fullName': fullName,
        'email': email,
        'photoUrl': photoUrl ?? '',
        'role': role,
        'addresses': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Never overwrite role on update
      await userRef.update({
        'fullName': fullName,
        'email': email,
        'photoUrl': photoUrl ?? '',
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  // Ensures doc exists for orphaned Auth accounts (no role → defaults to customer)
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

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // 로그인 상태 유지를 위한 키
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _userEmailKey = 'userEmail';
  static const String _userPasswordKey = 'userPassword';
  static const String _userTypeKey = 'userType';

  // SharedPreferences 인스턴스
  late SharedPreferences _prefs;

  // 초기화 메서드
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // 로그인 상태 확인
  Future<bool> isLoggedIn() async {
    await initialize();
    return _prefs.getBool(_isLoggedInKey) ?? false;
  }

  // 자동 로그인 시도
  Future<User?> autoLogin() async {
    try {
      // Firebase Auth의 현재 사용자 확인
      if (_auth.currentUser != null) {
        return _auth.currentUser;
      }

      // 저장된 이메일과 비밀번호로 로그인 시도
      final email = await _secureStorage.read(key: _userEmailKey);
      final password = await _secureStorage.read(key: _userPasswordKey);
      
      if (email != null && password != null) {
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return userCredential.user;
      }
    } catch (e) {
      print('자동 로그인 실패: $e');
      await signOut(context: null); // 로그인 실패 시 저장된 정보 삭제
    }
    return null;
  }

  // 로그인 정보 저장
  Future<void> _saveLoginInfo(String email, String password, String userType) async {
    await _secureStorage.write(key: _userEmailKey, value: email);
    await _secureStorage.write(key: _userPasswordKey, value: password);
    await _secureStorage.write(key: _userTypeKey, value: userType);
  }

  // 로그인 정보 삭제
  Future<void> _clearLoginInfo() async {
    await _secureStorage.delete(key: _userEmailKey);
    await _secureStorage.delete(key: _userPasswordKey);
    await _secureStorage.delete(key: _userTypeKey);
  }

  // 이메일/비밀번호 로그인
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 로그인 정보 저장
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user?.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final userType = userData['isParent'] ? 'parent' : 'child';
        await _saveLoginInfo(email, password, userType);
      }

      return userCredential.user;
    } catch (e) {
      throw Exception('로그인 실패: $e');
    }
  }

  // 구글 로그인
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // 로그인 정보 저장
      await _secureStorage.write(
        key: 'google_sign_in',
        value: 'true',
      );

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // 로그아웃
  Future<void> signOut({BuildContext? context}) async {
    try {
      // SharedPreferences 초기화
      _prefs = await SharedPreferences.getInstance();
      
      // 구글 로그인 정보 삭제
      await _googleSignIn.signOut();
      await _secureStorage.delete(key: 'google_sign_in');
      
      // Firebase 로그아웃
      await _auth.signOut();
      
      // 로그인 정보 삭제
      await _clearLoginInfo();
      
      // SharedPreferences 로그인 상태 초기화
      await _prefs.setBool(_isLoggedInKey, false);

      // 로그인 화면으로 이동
      if (context?.mounted == true) {
        Navigator.pushNamedAndRemoveUntil(context!, '/login', (route) => false);
      }
    } catch (e) {
      print('로그아웃 실패: $e');
      rethrow;
    }
  }

  // 현재 사용자 정보 가져오기
  User? get currentUser => _auth.currentUser;

  // 사용자 정보 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 사용자 타입 가져오기
  Future<String?> getUserType() async {
    return await _secureStorage.read(key: _userTypeKey);
  }

  Future<bool> isSignedIn() async {
    final email = await _secureStorage.read(key: _userEmailKey);
    final password = await _secureStorage.read(key: _userPasswordKey);
    final googleSignIn = await _secureStorage.read(key: 'google_sign_in');

    if (email != null && password != null) {
      try {
        await signInWithEmailAndPassword(email, password);
        return true;
      } catch (e) {
        return false;
      }
    } else if (googleSignIn == 'true') {
      try {
        await signInWithGoogle();
        return true;
      } catch (e) {
        return false;
      }
    }

    return false;
  }

  Future<User?> signUpWithEmailAndPassword(
    String email,
    String password,
    String nickname,
    bool isParent,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'nickname': nickname,
          'isParent': isParent,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 회원가입 후 로그인 정보 저장
        await _saveLoginInfo(email, password, isParent ? 'parent' : 'child');
      }

      return user;
    } catch (e) {
      throw Exception('회원가입 실패: $e');
    }
  }

  Future<bool> isEmailRegistered(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
} 
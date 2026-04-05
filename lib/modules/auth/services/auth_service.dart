import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 取得目前登入用戶
  static User? get currentUser => _auth.currentUser;

  // 是否已登入
  static bool get isLoggedIn => _auth.currentUser != null;

  // 取得用戶 UID
  static String? get userId => _auth.currentUser?.uid;

  // Google 登入
  static Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      return userCredential.user;
    } catch (e) {
      print('Google 登入失敗: $e');
      return null;
    }
  }

  // 登出
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // 監聽登入狀態變化
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
}

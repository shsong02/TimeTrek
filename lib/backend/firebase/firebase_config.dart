import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyAQaF18vP85sW0ztZBhPR7TEqGoMeWeF-0",
            authDomain: "plan-thwcdc.firebaseapp.com",
            projectId: "plan-thwcdc",
            storageBucket: "plan-thwcdc.appspot.com",
            messagingSenderId: "644762479095",
            appId: "1:644762479095:web:fc73ec0013aaecf76b66f2"));
  } else {
    await Firebase.initializeApp();
  }
}

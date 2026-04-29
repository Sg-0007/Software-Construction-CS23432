import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'login_screen.dart';
import 'chat_screen.dart';
import 'profile_form_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  _AuthGateState createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _hasProfile = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    
    _supabase.auth.onAuthStateChange.listen((data) async {
       if (!mounted) return;
       final session = data.session;
       setState(() {
         _isAuthenticated = session != null;
         if (session == null) {
           _isLoading = false;
         }
       });
       
       if (session != null) {
          _fetchProfile(session.user.id);
       }
    });
  }

  Future<void> _checkAuth() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      final profile = await _supabase.from('profiles').select().eq('id', userId).maybeSingle();
      if (mounted) {
         setState(() {
            _hasProfile = profile != null;
            _isLoading = false;
         });
      }
    } catch (e) {
      if (mounted) {
         setState(() {
            _hasProfile = false;
            _isLoading = false;
         });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
     if (_isLoading) {
       return Scaffold(
         backgroundColor: Colors.grey[50],
         body: Center(
           child: SpinKitThreeBounce(color: Colors.indigo, size: 24),
         ),
       );
     }
     
     if (!_isAuthenticated) return const LoginScreen();
     if (_hasProfile) return const ChatScreen();
     return const ProfileFormScreen();
  }
}

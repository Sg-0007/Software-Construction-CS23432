import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/scheme.dart';

class ApiService {
  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:5000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    } else {
      return 'http://127.0.0.1:5000';
    }
  }

  static Future<Map<String, dynamic>> sendMessage(String message) async {
    final url = Uri.parse('$_baseUrl/api/chat');
    
    Map<String, dynamic>? profile;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        profile = await Supabase.instance.client.from('profiles').select().eq('id', userId).maybeSingle();
      }
    } catch (e) {
      print('Supabase profile fetch error: $e');
    }
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message, 'profile': profile}),
      ).timeout(const Duration(seconds: 45));

      print('RAW API RESPONSE: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        List<Scheme>? schemes;
        String? command;
        
        if (data['data'] != null) {
          if (data['data'] is List) {
            schemes = (data['data'] as List).map((e) => Scheme.fromJson(e)).toList();
          } else if (data['data'] is Map && data['data']['command'] == 'show_schemes') {
            command = 'show_schemes';
            if (data['data']['schemes'] != null) {
              schemes = (data['data']['schemes'] as List).map((e) => Scheme.fromJson(e)).toList();
            }
          }
          schemes = schemes?.where((s) => s.name != 'Unknown Scheme').toList();
        }
        
        return {
          'text': data['response'] ?? '',
          'schemes': schemes?.isEmpty == true ? null : schemes,
          'action': data['action'] ?? 'none',
          'command': command
        };
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('API Error: $e');
      throw Exception('Failed to connect to the server. Please check your connection.');
    }
  }

  static Future<Map<String, dynamic>> submitProfile(Map<String, dynamic> profileData) async {
    final url = Uri.parse('$_baseUrl/api/submit_profile');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profileData),
      ).timeout(const Duration(seconds: 45));

      print('RAW API RESPONSE: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        List<Scheme>? schemes;
        if (data['data'] != null && data['data'] is List) {
          schemes = (data['data'] as List).map((e) => Scheme.fromJson(e)).toList();
          schemes = schemes.where((s) => s.name != 'Unknown Scheme').toList();
        }
        
        return {
          'text': data['response'] ?? '',
          'schemes': schemes?.isEmpty == true ? null : schemes,
        };
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('API Error: $e');
      throw Exception('Failed to submit profile. Please try again.');
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/flashcard.dart';

class BackendService {
  static const String _baseUrl = 'http://127.0.0.1:5000';
  static bool _isAvailable = false;

  static bool get isAvailable => _isAvailable;
  static String get baseUrl => _baseUrl;

  /// Check if the backend server is available
  static Future<bool> checkAvailability() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      _isAvailable = response.statusCode == 200;
      return _isAvailable;
    } catch (e) {
      print('Backend server not available: $e');
      _isAvailable = false;
      return false;
    }
  }

  /// Generate flashcards using the backend server
  static Future<List<Flashcard>> generateFlashcards(String topic, {int count = 10}) async {
    try {
      // Check if server is available first
      if (!await checkAvailability()) {
        throw Exception('Backend server is not available at $_baseUrl');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': topic,  // Changed from 'topic' to 'prompt'
          'count': count,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['flashcards'] != null) {
          final List<dynamic> flashcardsJson = data['flashcards'];
          
          return flashcardsJson.map((item) {
            return Flashcard(
              question: item['question']?.toString() ?? '',
              answer: item['answer']?.toString() ?? '',
            );
          }).toList();
        } else {
          throw Exception(data['error'] ?? 'Unknown error from backend');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating flashcards via backend: $e');
      throw Exception('Failed to generate flashcards: $e');
    }
  }

  /// Generate a set name based on the topic
  static String generateSetName(String topic) {
    final words = topic.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'AI Generated Set';
    
    final capitalized = words.map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
    return '$capitalized Flashcards';
  }

  /// Get server status information for debugging
  static Future<Map<String, dynamic>> getServerStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'available': false,
          'error': 'HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'available': false,
        'error': e.toString(),
      };
    }
  }
}

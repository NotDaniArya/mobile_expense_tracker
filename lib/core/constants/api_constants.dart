import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static final String geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
}

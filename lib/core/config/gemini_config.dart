import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:visiospark_2025/core/config/api_constant.dart';

class GeminiConfig {
  static GenerativeModel? _model;

  static GenerativeModel get model {
    _model ??= GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: APIConstant.geminiAPIKEy,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048,
      ),
    );
    return _model!;
  }

  static const String systemPrompt = '''
You are a helpful AI assistant for our app. Be concise, friendly, and helpful.
Provide accurate information and admit when you don't know something.
Format your responses using markdown when appropriate.
''';

  static bool get isConfigured =>
      APIConstant.geminiAPIKEy != 'YOUR_GEMINI_API_KEY';
}

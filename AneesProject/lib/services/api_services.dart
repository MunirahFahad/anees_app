import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/place_model.dart';

class ApiService {
  static const String _baseUrl = 'https://elmodels.ngrok.app';
  static const String _apiKey  = 'sk-w7u3JSrWgudiRE5Ew1K11Q';
  static const String _model   = 'nuha-2.0';

  // ── Load route from JSON ──────────────────────────────────────────────────
  Future<List<PlaceModel>> loadPlaces() async {
    final raw  = await rootBundle.loadString('assets/places.json');
    final list = json.decode(raw) as List<dynamic>;
    return list.map((item) => PlaceModel.fromJson(item)).toList();
  }

  // ── Story prompt (uses history + sensory + role) ──────────────────────────
  String _storyPrompt(PlaceModel place) {
    String extra = switch (place.role) {
      'intro'      => 'ابدأ بترحيب دافئ يجعل المستخدم يشعر بأنه وصل لمكان مميز.',
      'movement'   => 'اجعل السرد يعكس الحركة والانتقال التدريجي بين المساحات.',
      'transition' => 'هيّئ المستخدم نفسياً للدخول إلى مساحة مختلفة الطابع.',
      'ending'     => 'اختم بإحساس بالاكتمال واستحضر أهمية المكان في التاريخ.',
      _            => '',
    };

    return '''
أنت راوٍ صوتي يرافق مستخدمًا في موقع تراثي.

الموقع: ${place.name}
المعلومات التاريخية: ${place.history}
الإحساس الحسي: ${place.sensory}

$extra

اكتب 7 إلى 10 جمل بهذا الترتيب الثابت:
1. جملة أولى: صف شكل المكان وحجمه وطابعه المعماري فقط (ليس الهواء أو الأرضية)
2. جملة ثانية:انتقل للتاريخ — ما الذي كان يحدث هنا؟ من كان يأتي إليه؟ 
3. جملة ثالثة: صف الإحساس العام بالمكان (الهدوء، الاتساع، الهيبة)
4. جملة رابعة: أضف تفصيلاً تاريخياً مهماً (حدث، قرار، شخصية)
5. جملة خامسة: اختم بجملة تربط الماضي بالحاضر

القواعد:
- لا تبدأ بـ أهلاً أو مرحباً
- لا تستخدم: انظر، ترى
- الأسلوب: سردي، هادئ، حي
''';
  }

  // ── Transition prompt (plays WHILE walking to next point) ────────────────
  String _transitionPrompt(PlaceModel from, PlaceModel to) {
    return '''
أنت مرشد صوتي والمستخدم يمشي الآن من "${from.name}" نحو "${to.name}".
نص الانتقال المحدد: ${from.transition}
اكتب جملة أو جملتين قصيرتين تشجعان المستخدم على الاستمرار في المشي.
اجعل الأسلوب هادئًا وطبيعيًا مناسبًا للاستماع أثناء المشي.
''';
  }

  // ── Q&A prompt (user asked a question about the current place) ───────────
  String _qaPrompt(PlaceModel place, String question) {
    return '''
أنت مرشد صوتي متخصص في التاريخ والتراث السعودي ولديك معرفة واسعة بالتاريخ الإسلامي والعربي.
المستخدم يقف الآن عند: ${place.name}

سياق المكان: ${place.qaContext}
معلومات إضافية: ${place.history}

سؤال المستخدم: $question

تعليمات:
- استخدم معرفتك الكاملة بالتاريخ السعودي والإسلامي للإجابة، لا تقتصر على السياق أعلاه فقط
- إذا كان السؤال عن تاريخ أو سنة أو شخصية، أجب من معرفتك المباشرة
- إذا لم تكن متأكداً من المعلومة، قل ذلك بصدق
- أجب بـ 2 إلى 3 جمل قصيرة بأسلوب مرشد سياحي ودود
- لا تستخدم أسلوباً أكاديمياً أو رسمياً
''';
  }

  // ── Call LLM ──────────────────────────────────────────────────────────────
  Future<String> _callLlm(String prompt) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [{'role': 'user', 'content': prompt}],
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('LLM ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['choices'][0]['message']['content'] as String;
  }

  // ── Voice shaping for story ───────────────────────────────────────────────
  String _shape(String text) {
    text = text.replaceAll('،', '...');
    final sentences = text
        .replaceAll('؟', '.').replaceAll('!', '.')
        .split('.').map((s) => s.trim()).where((s) => s.isNotEmpty)
        .take(7).toList();
    return '${sentences.join('...\n')}...\n.';
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Story narration for arriving at a checkpoint.
  Future<String> getStory(PlaceModel place) async =>
      _shape(await _callLlm(_storyPrompt(place)));

  /// Short narration played WHILE walking between two points.
  Future<String> getTransition(PlaceModel from, PlaceModel to) async =>
      await _callLlm(_transitionPrompt(from, to));

  /// Answer a user's spoken question about the current place.
  Future<String> answerQuestion(PlaceModel place, String question) async =>
      await _callLlm(_qaPrompt(place, question));
}

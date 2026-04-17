import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/place_model.dart';

class ApiService {
  static const String _baseUrl = 'https://elmodels.ngrok.app';
  static const String _apiKey  = 'Your LLM key Here';
  static const String _model   = 'nuha-2.0';

  // ── Load route from JSON ──────────────────────────────────────────────────
  Future<List<PlaceModel>> loadPlaces() async {
    final raw  = await rootBundle.loadString('assets/places.json');
    final list = json.decode(raw) as List<dynamic>;
    return list.map((item) => PlaceModel.fromJson(item)).toList();
  }

  // ── Story prompt (uses history + sensory + role) ──────────────────────────
  String _storyPrompt(PlaceModel place) {
    String extra = "";

    if (place.role == "intro") {
      extra = "ابدأ بتقديم واضح يعرّف المستخدم بالمكان وأهميته كبداية للرحلة.";
    } else if (place.role == "movement") {
      extra = "اجعل الوصف يعكس الحركة والانتقال بين الأماكن بشكل طبيعي.";
    } else if (place.role == "transition") {
      extra = "هيّئ المستخدم للدخول إلى مساحة مختلفة ذات طابع جديد.";
    } else if (place.role == "ending") {
      extra = "اختم التجربة بشرح أهمية المكان وتأثيره، مع نهاية هادئة.";
    }

    return """
أنت مرشد صوتي محترف يرافق مستخدمًا كفيفًا أثناء المشي، ويعتمد على الوصف الدقيق لمساعدته على تخيّل المكان وفهمه.

الموقع: ${place.name}
نوع النقطة: ${place.role}

ملخص:
${place.summary}

المعلومات التاريخية:
${place.history}

وصف المكان:
${place.sensory}

الانتقال:
${place.transition}

$extra

المطلوب:
- اكتب 4 إلى 5 جمل
- ابدأ بوصف واضح لشكل المكان (المساحة، ترتيب المباني، الإحساس العام)
- بعد ذلك مباشرة، اشرح ماذا كان يحدث في هذا المكان تاريخيًا ولماذا هو مهم
- اربط دائمًا بين شكل المكان ووظيفته في الماضي (كيف كان يُستخدم ولماذا يبدو بهذا الشكل)
- لا تركز فقط على تفاصيل الأرض أو الأبواب، بل صف المكان ككل (الساحة، المباني، الفراغ، الحركة)
- اجعل كل جملة تضيف معلومة جديدة (وصف أو تاريخ)
- اجعل السرد متوازنًا: نصفه وصف حسي، ونصفه معلومات تاريخية
- استخدم أسلوبًا هادئًا وسلسًا ومناسبًا للاستماع الصوتي
- استخدم جمل متوسطة الطول
- تجنب أي تعبير يعتمد على الرؤية المباشرة (مثل: انظر، ترى)
- اجعل المستخدم يشعر وكأنه يفهم المكان ويتخيل تاريخه في نفس الوقت
""";
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
        .take(3).toList();
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

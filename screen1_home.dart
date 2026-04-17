class PlaceModel {
  final int         id;
  final String      name;
  final double      lat;
  final double      lng;
  final double      radius;
  final String      type;
  final String      role;
  final String      summary;
  final List<String> keywords;
  final String      history;
  final String      sensory;
  final String      transition;
  final String      qaContext;  // used as LLM context for Q&A answers

  const PlaceModel({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.type,
    required this.role,
    required this.summary,
    required this.keywords,
    required this.history,
    required this.sensory,
    required this.transition,
    required this.qaContext,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) => PlaceModel(
    id:         json['id']         ?? 0,
    name:       json['name']       ?? '',
    lat:        (json['lat']    as num?)?.toDouble() ?? 0.0,
    lng:        (json['lng']    as num?)?.toDouble() ?? 0.0,
    radius:     (json['radius'] as num?)?.toDouble() ?? 0.0,
    type:       json['type']       ?? '',
    role:       json['role']       ?? '',
    summary:    json['summary']    ?? '',
    keywords:   (json['keywords'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? [],
    history:    json['history']    ?? '',
    sensory:    json['sensory']    ?? '',
    transition: json['transition'] ?? '',
    qaContext:  json['qa_context'] ?? '',
  );
}

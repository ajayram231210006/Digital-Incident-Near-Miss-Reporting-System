const bool kAiAnalysisEnabled = true;
const String kAiModel = 'gemini-2.5-flash';

Map<String, dynamic> buildAiAnalysisPlaceholder() {
  if (kAiAnalysisEnabled) {
    return {
      'status': 'pending',
      'model': kAiModel,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  return {
    'status': 'disabled',
    'reason':
        'AI suggestions are temporarily unavailable while backend deployment is disabled.',
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

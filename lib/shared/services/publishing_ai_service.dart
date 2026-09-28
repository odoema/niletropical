import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class PublishingAiResult {
  const PublishingAiResult({required this.result, required this.model});
  final Map<String, dynamic> result;
  final String model;
}

class PublishingAiService {
  static Future<PublishingAiResult> assist({
    required String action,
    String channel = 'website',
    String? itemId,
    required Map<String, dynamic> article,
    String source = '',
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      'publishing-ai-assist',
      body: {
        'action': action,
        'channel': channel,
        'item_id': itemId,
        'article': article,
        'source': source,
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    return PublishingAiResult(
      result: Map<String, dynamic>.from(data['result'] as Map),
      model: data['model']?.toString() ?? 'AI',
    );
  }
}

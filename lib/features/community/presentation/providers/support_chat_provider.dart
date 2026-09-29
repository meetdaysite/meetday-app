import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

class SupportChatReplyTo {
  const SupportChatReplyTo({
    required this.id,
    required this.senderType,
    required this.content,
    this.hasMedia = false,
  });

  final String id;
  final String senderType;
  final String content;
  final bool hasMedia;

  factory SupportChatReplyTo.fromJson(Map<String, dynamic> json) {
    return SupportChatReplyTo(
      id: (json['id'] ?? '').toString(),
      senderType: (json['senderType'] ?? 'ADMIN').toString().toUpperCase(),
      content: (json['content'] ?? '').toString(),
      hasMedia: json['hasMedia'] == true || json['mediaKey'] != null,
    );
  }
}

class SupportChatMessage {
  const SupportChatMessage({
    required this.id,
    required this.senderType,
    required this.content,
    this.senderId,
    this.mediaUrl,
    this.editedAt,
    this.deletedAt,
    this.createdAt,
    this.replyTo,
    this.wasRedacted = false,
  });

  final String id;
  final String senderType; // 'USER', 'BOT', 'ADMIN'
  final String content;
  final String? senderId;
  final String? mediaUrl;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final SupportChatReplyTo? replyTo;
  final bool wasRedacted;

  bool get isMine => senderType.toUpperCase() == 'USER';
  bool get isBot => senderType.toUpperCase() == 'BOT';
  bool get isAdmin => senderType.toUpperCase() == 'ADMIN';
  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null;
  bool get isSystem => content.startsWith('[System]') || content.startsWith('[system]');

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    try {
      return DateTime.parse(val.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  factory SupportChatMessage.fromJson(Map<String, dynamic> json) {
    SupportChatReplyTo? reply;
    if (json['replyTo'] is Map) {
      reply = SupportChatReplyTo.fromJson(Map<String, dynamic>.from(json['replyTo'] as Map));
    }

    return SupportChatMessage(
      id: (json['id'] ?? '').toString(),
      senderType: (json['senderType'] ?? 'ADMIN').toString().toUpperCase(),
      content: (json['content'] ?? '').toString(),
      senderId: json['senderId']?.toString(),
      mediaUrl: json['mediaUrl'] as String?,
      editedAt: _parseDate(json['editedAt']),
      deletedAt: _parseDate(json['deletedAt']),
      createdAt: _parseDate(json['createdAt']),
      replyTo: reply,
      wasRedacted: json['wasRedacted'] == true,
    );
  }
}

// ─── Support Chat Provider ───────────────────────────────────────────────────

final supportChatMessagesProvider = FutureProvider.autoDispose<List<SupportChatMessage>>((ref) async {
  final api = ref.watch(apiClientProvider);

  try {
    final res = await api.dio.get<dynamic>('/meetday-chat/messages', queryParameters: {'context': 'HOST'});
    final data = res.data;

    List<dynamic> list = [];
    if (data is Map) {
      if (data['data'] is Map && (data['data'] as Map)['messages'] is List) {
        list = (data['data'] as Map)['messages'] as List;
      } else if (data['messages'] is List) {
        list = data['messages'] as List;
      } else if (data['data'] is List) {
        list = data['data'] as List;
      }
    } else if (data is List) {
      list = data;
    }

    return list
        .whereType<Map>()
        .map((m) => SupportChatMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  } catch (e) {
    debugPrint('Error loading Meetday support chat messages: $e');
    return [];
  }
});

// ─── API Action Helpers ──────────────────────────────────────────────────────

Future<SupportChatMessage?> sendSupportChatMessageApi(
  ApiClient api, {
  required String content,
  String? mediaUrl,
  String? replyToId,
  String context = 'HOST',
}) async {
  final payload = <String, dynamic>{
    'content': content.trim(),
  };
  if (mediaUrl != null && mediaUrl.isNotEmpty) {
    payload['mediaUrl'] = mediaUrl;
  }
  if (replyToId != null && replyToId.isNotEmpty) {
    payload['replyToId'] = replyToId;
  }

  final res = await api.dio.post<dynamic>(
    '/meetday-chat/messages',
    data: payload,
    queryParameters: {'context': context},
  );

  final resData = res.data;
  if (resData is Map) {
    final inner = resData['data'] is Map ? resData['data'] as Map : resData;
    return SupportChatMessage.fromJson(Map<String, dynamic>.from(inner));
  }
  return null;
}

Future<void> editSupportChatMessageApi(
  ApiClient api,
  String messageId,
  String newContent,
) async {
  await api.dio.patch<dynamic>(
    '/meetday-chat/messages/$messageId',
    data: {'content': newContent.trim()},
  );
}

Future<void> deleteSupportChatMessageApi(
  ApiClient api,
  String messageId,
) async {
  await api.dio.delete<dynamic>('/meetday-chat/messages/$messageId');
}

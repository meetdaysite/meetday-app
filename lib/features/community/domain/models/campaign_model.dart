import 'package:freezed_annotation/freezed_annotation.dart';

part 'campaign_model.freezed.dart';
part 'campaign_model.g.dart';

@freezed
class Campaign with _$Campaign {
  const factory Campaign({
    required String id,
    required String brandName,
    required String title,
    required double budget,
    required String category,
    required DateTime deadline,
    required String status,
    required String description,
  }) = _Campaign;

  factory Campaign.fromJson(Map<String, dynamic> json) => _$CampaignFromJson(json);
}

@freezed
class Space with _$Space {
  const factory Space({
    required String id,
    required String name,
    required String location,
    required int capacity,
    required String status,
    required int totalBookings,
    required List<String> amenities,
  }) = _Space;

  factory Space.fromJson(Map<String, dynamic> json) => _$SpaceFromJson(json);
}

@freezed
class Payout with _$Payout {
  const factory Payout({
    required String id,
    required DateTime date,
    required String dealName,
    required double amount,
    required String status,
  }) = _Payout;

  factory Payout.fromJson(Map<String, dynamic> json) => _$PayoutFromJson(json);
}

@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required String senderId,
    required String senderName,
    required String content,
    required DateTime timestamp,
    required bool isRead,
    @Default('') String type,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}

@freezed
class Conversation with _$Conversation {
  const factory Conversation({
    required String id,
    required String participantId,
    required String participantName,
    required String lastMessage,
    required DateTime lastMessageTime,
    required int unreadCount,
    @Default('') String type,
  }) = _Conversation;

  factory Conversation.fromJson(Map<String, dynamic> json) => _$ConversationFromJson(json);
}

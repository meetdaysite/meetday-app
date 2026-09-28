// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'campaign_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Campaign _$CampaignFromJson(Map<String, dynamic> json) => _Campaign(
  id: json['id'] as String,
  brandName: json['brandName'] as String,
  title: json['title'] as String,
  budget: (json['budget'] as num).toDouble(),
  category: json['category'] as String,
  deadline: DateTime.parse(json['deadline'] as String),
  status: json['status'] as String,
  description: json['description'] as String,
);

Map<String, dynamic> _$CampaignToJson(_Campaign instance) => <String, dynamic>{
  'id': instance.id,
  'brandName': instance.brandName,
  'title': instance.title,
  'budget': instance.budget,
  'category': instance.category,
  'deadline': instance.deadline.toIso8601String(),
  'status': instance.status,
  'description': instance.description,
};

_Space _$SpaceFromJson(Map<String, dynamic> json) => _Space(
  id: json['id'] as String,
  name: json['name'] as String,
  location: json['location'] as String,
  capacity: (json['capacity'] as num).toInt(),
  status: json['status'] as String,
  totalBookings: (json['totalBookings'] as num).toInt(),
  amenities: (json['amenities'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$SpaceToJson(_Space instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'location': instance.location,
  'capacity': instance.capacity,
  'status': instance.status,
  'totalBookings': instance.totalBookings,
  'amenities': instance.amenities,
};

_Payout _$PayoutFromJson(Map<String, dynamic> json) => _Payout(
  id: json['id'] as String,
  date: DateTime.parse(json['date'] as String),
  dealName: json['dealName'] as String,
  amount: (json['amount'] as num).toDouble(),
  status: json['status'] as String,
);

Map<String, dynamic> _$PayoutToJson(_Payout instance) => <String, dynamic>{
  'id': instance.id,
  'date': instance.date.toIso8601String(),
  'dealName': instance.dealName,
  'amount': instance.amount,
  'status': instance.status,
};

_Message _$MessageFromJson(Map<String, dynamic> json) => _Message(
  id: json['id'] as String,
  senderId: json['senderId'] as String,
  senderName: json['senderName'] as String,
  content: json['content'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  isRead: json['isRead'] as bool,
  type: json['type'] as String? ?? '',
);

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
  'id': instance.id,
  'senderId': instance.senderId,
  'senderName': instance.senderName,
  'content': instance.content,
  'timestamp': instance.timestamp.toIso8601String(),
  'isRead': instance.isRead,
  'type': instance.type,
};

_Conversation _$ConversationFromJson(Map<String, dynamic> json) =>
    _Conversation(
      id: json['id'] as String,
      participantId: json['participantId'] as String,
      participantName: json['participantName'] as String,
      lastMessage: json['lastMessage'] as String,
      lastMessageTime: DateTime.parse(json['lastMessageTime'] as String),
      unreadCount: (json['unreadCount'] as num).toInt(),
      type: json['type'] as String? ?? '',
    );

Map<String, dynamic> _$ConversationToJson(_Conversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'participantId': instance.participantId,
      'participantName': instance.participantName,
      'lastMessage': instance.lastMessage,
      'lastMessageTime': instance.lastMessageTime.toIso8601String(),
      'unreadCount': instance.unreadCount,
      'type': instance.type,
    };

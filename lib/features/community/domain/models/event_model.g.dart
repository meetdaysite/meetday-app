// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Event _$EventFromJson(Map<String, dynamic> json) => _Event(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  date: DateTime.parse(json['date'] as String),
  location: json['location'] as String,
  capacity: (json['capacity'] as num).toInt(),
  registered: (json['registered'] as num).toInt(),
  price: (json['price'] as num).toDouble(),
  status: json['status'] as String,
  imageUrl: json['imageUrl'] as String? ?? '',
);

Map<String, dynamic> _$EventToJson(_Event instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'description': instance.description,
  'date': instance.date.toIso8601String(),
  'location': instance.location,
  'capacity': instance.capacity,
  'registered': instance.registered,
  'price': instance.price,
  'status': instance.status,
  'imageUrl': instance.imageUrl,
};

_Attendee _$AttendeeFromJson(Map<String, dynamic> json) => _Attendee(
  id: json['id'] as String,
  name: json['name'] as String,
  email: json['email'] as String,
  status: json['status'] as String,
  registrationDate: DateTime.parse(json['registrationDate'] as String),
  phone: json['phone'] as String?,
);

Map<String, dynamic> _$AttendeeToJson(_Attendee instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'status': instance.status,
  'registrationDate': instance.registrationDate.toIso8601String(),
  'phone': instance.phone,
};

_EventStats _$EventStatsFromJson(Map<String, dynamic> json) => _EventStats(
  totalEvents: (json['totalEvents'] as num).toInt(),
  totalAttendees: (json['totalAttendees'] as num).toInt(),
  checkedIn: (json['checkedIn'] as num).toInt(),
  revenue: (json['revenue'] as num).toDouble(),
  averageAttendance: (json['averageAttendance'] as num).toDouble(),
);

Map<String, dynamic> _$EventStatsToJson(_EventStats instance) =>
    <String, dynamic>{
      'totalEvents': instance.totalEvents,
      'totalAttendees': instance.totalAttendees,
      'checkedIn': instance.checkedIn,
      'revenue': instance.revenue,
      'averageAttendance': instance.averageAttendance,
    };

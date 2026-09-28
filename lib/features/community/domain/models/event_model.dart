import 'package:freezed_annotation/freezed_annotation.dart';

part 'event_model.freezed.dart';
part 'event_model.g.dart';

@freezed
class Event with _$Event {
  const factory Event({
    required String id,
    required String title,
    required String description,
    required DateTime date,
    required String location,
    required int capacity,
    required int registered,
    required double price,
    required String status,
    @Default('') String imageUrl,
  }) = _Event;

  factory Event.fromJson(Map<String, dynamic> json) =>
      _$EventFromJson(json);
}

@freezed
class Attendee with _$Attendee {
  const factory Attendee({
    required String id,
    required String name,
    required String email,
    required String status,
    required DateTime registrationDate,
    String? phone,
  }) = _Attendee;

  factory Attendee.fromJson(Map<String, dynamic> json) =>
      _$AttendeeFromJson(json);
}

@freezed
class EventStats with _$EventStats {
  const factory EventStats({
    required int totalEvents,
    required int totalAttendees,
    required int checkedIn,
    required double revenue,
    required double averageAttendance,
  }) = _EventStats;

  factory EventStats.fromJson(Map<String, dynamic> json) =>
      _$EventStatsFromJson(json);
}

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'event_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Event {

 String get id; String get title; String get description; DateTime get date; String get location; int get capacity; int get registered; double get price; String get status; String get imageUrl;
/// Create a copy of Event
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EventCopyWith<Event> get copyWith => _$EventCopyWithImpl<Event>(this as Event, _$identity);

  /// Serializes this Event to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Event&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.date, date) || other.date == date)&&(identical(other.location, location) || other.location == location)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.registered, registered) || other.registered == registered)&&(identical(other.price, price) || other.price == price)&&(identical(other.status, status) || other.status == status)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,date,location,capacity,registered,price,status,imageUrl);

@override
String toString() {
  return 'Event(id: $id, title: $title, description: $description, date: $date, location: $location, capacity: $capacity, registered: $registered, price: $price, status: $status, imageUrl: $imageUrl)';
}


}

/// @nodoc
abstract mixin class $EventCopyWith<$Res>  {
  factory $EventCopyWith(Event value, $Res Function(Event) _then) = _$EventCopyWithImpl;
@useResult
$Res call({
 String id, String title, String description, DateTime date, String location, int capacity, int registered, double price, String status, String imageUrl
});




}
/// @nodoc
class _$EventCopyWithImpl<$Res>
    implements $EventCopyWith<$Res> {
  _$EventCopyWithImpl(this._self, this._then);

  final Event _self;
  final $Res Function(Event) _then;

/// Create a copy of Event
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = null,Object? date = null,Object? location = null,Object? capacity = null,Object? registered = null,Object? price = null,Object? status = null,Object? imageUrl = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,registered: null == registered ? _self.registered : registered // ignore: cast_nullable_to_non_nullable
as int,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Event].
extension EventPatterns on Event {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Event value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Event() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Event value)  $default,){
final _that = this;
switch (_that) {
case _Event():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Event value)?  $default,){
final _that = this;
switch (_that) {
case _Event() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String description,  DateTime date,  String location,  int capacity,  int registered,  double price,  String status,  String imageUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Event() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.date,_that.location,_that.capacity,_that.registered,_that.price,_that.status,_that.imageUrl);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String description,  DateTime date,  String location,  int capacity,  int registered,  double price,  String status,  String imageUrl)  $default,) {final _that = this;
switch (_that) {
case _Event():
return $default(_that.id,_that.title,_that.description,_that.date,_that.location,_that.capacity,_that.registered,_that.price,_that.status,_that.imageUrl);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String description,  DateTime date,  String location,  int capacity,  int registered,  double price,  String status,  String imageUrl)?  $default,) {final _that = this;
switch (_that) {
case _Event() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.date,_that.location,_that.capacity,_that.registered,_that.price,_that.status,_that.imageUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Event implements Event {
  const _Event({required this.id, required this.title, required this.description, required this.date, required this.location, required this.capacity, required this.registered, required this.price, required this.status, this.imageUrl = ''});
  factory _Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

@override final  String id;
@override final  String title;
@override final  String description;
@override final  DateTime date;
@override final  String location;
@override final  int capacity;
@override final  int registered;
@override final  double price;
@override final  String status;
@override@JsonKey() final  String imageUrl;

/// Create a copy of Event
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EventCopyWith<_Event> get copyWith => __$EventCopyWithImpl<_Event>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Event&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.date, date) || other.date == date)&&(identical(other.location, location) || other.location == location)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.registered, registered) || other.registered == registered)&&(identical(other.price, price) || other.price == price)&&(identical(other.status, status) || other.status == status)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,date,location,capacity,registered,price,status,imageUrl);

@override
String toString() {
  return 'Event(id: $id, title: $title, description: $description, date: $date, location: $location, capacity: $capacity, registered: $registered, price: $price, status: $status, imageUrl: $imageUrl)';
}


}

/// @nodoc
abstract mixin class _$EventCopyWith<$Res> implements $EventCopyWith<$Res> {
  factory _$EventCopyWith(_Event value, $Res Function(_Event) _then) = __$EventCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String description, DateTime date, String location, int capacity, int registered, double price, String status, String imageUrl
});




}
/// @nodoc
class __$EventCopyWithImpl<$Res>
    implements _$EventCopyWith<$Res> {
  __$EventCopyWithImpl(this._self, this._then);

  final _Event _self;
  final $Res Function(_Event) _then;

/// Create a copy of Event
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = null,Object? date = null,Object? location = null,Object? capacity = null,Object? registered = null,Object? price = null,Object? status = null,Object? imageUrl = null,}) {
  return _then(_Event(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,registered: null == registered ? _self.registered : registered // ignore: cast_nullable_to_non_nullable
as int,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Attendee {

 String get id; String get name; String get email; String get status; DateTime get registrationDate; String? get phone;
/// Create a copy of Attendee
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttendeeCopyWith<Attendee> get copyWith => _$AttendeeCopyWithImpl<Attendee>(this as Attendee, _$identity);

  /// Serializes this Attendee to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Attendee&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.status, status) || other.status == status)&&(identical(other.registrationDate, registrationDate) || other.registrationDate == registrationDate)&&(identical(other.phone, phone) || other.phone == phone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,email,status,registrationDate,phone);

@override
String toString() {
  return 'Attendee(id: $id, name: $name, email: $email, status: $status, registrationDate: $registrationDate, phone: $phone)';
}


}

/// @nodoc
abstract mixin class $AttendeeCopyWith<$Res>  {
  factory $AttendeeCopyWith(Attendee value, $Res Function(Attendee) _then) = _$AttendeeCopyWithImpl;
@useResult
$Res call({
 String id, String name, String email, String status, DateTime registrationDate, String? phone
});




}
/// @nodoc
class _$AttendeeCopyWithImpl<$Res>
    implements $AttendeeCopyWith<$Res> {
  _$AttendeeCopyWithImpl(this._self, this._then);

  final Attendee _self;
  final $Res Function(Attendee) _then;

/// Create a copy of Attendee
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? email = null,Object? status = null,Object? registrationDate = null,Object? phone = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,registrationDate: null == registrationDate ? _self.registrationDate : registrationDate // ignore: cast_nullable_to_non_nullable
as DateTime,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Attendee].
extension AttendeePatterns on Attendee {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Attendee value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Attendee() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Attendee value)  $default,){
final _that = this;
switch (_that) {
case _Attendee():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Attendee value)?  $default,){
final _that = this;
switch (_that) {
case _Attendee() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String email,  String status,  DateTime registrationDate,  String? phone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Attendee() when $default != null:
return $default(_that.id,_that.name,_that.email,_that.status,_that.registrationDate,_that.phone);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String email,  String status,  DateTime registrationDate,  String? phone)  $default,) {final _that = this;
switch (_that) {
case _Attendee():
return $default(_that.id,_that.name,_that.email,_that.status,_that.registrationDate,_that.phone);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String email,  String status,  DateTime registrationDate,  String? phone)?  $default,) {final _that = this;
switch (_that) {
case _Attendee() when $default != null:
return $default(_that.id,_that.name,_that.email,_that.status,_that.registrationDate,_that.phone);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Attendee implements Attendee {
  const _Attendee({required this.id, required this.name, required this.email, required this.status, required this.registrationDate, this.phone});
  factory _Attendee.fromJson(Map<String, dynamic> json) => _$AttendeeFromJson(json);

@override final  String id;
@override final  String name;
@override final  String email;
@override final  String status;
@override final  DateTime registrationDate;
@override final  String? phone;

/// Create a copy of Attendee
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AttendeeCopyWith<_Attendee> get copyWith => __$AttendeeCopyWithImpl<_Attendee>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AttendeeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Attendee&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.status, status) || other.status == status)&&(identical(other.registrationDate, registrationDate) || other.registrationDate == registrationDate)&&(identical(other.phone, phone) || other.phone == phone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,email,status,registrationDate,phone);

@override
String toString() {
  return 'Attendee(id: $id, name: $name, email: $email, status: $status, registrationDate: $registrationDate, phone: $phone)';
}


}

/// @nodoc
abstract mixin class _$AttendeeCopyWith<$Res> implements $AttendeeCopyWith<$Res> {
  factory _$AttendeeCopyWith(_Attendee value, $Res Function(_Attendee) _then) = __$AttendeeCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String email, String status, DateTime registrationDate, String? phone
});




}
/// @nodoc
class __$AttendeeCopyWithImpl<$Res>
    implements _$AttendeeCopyWith<$Res> {
  __$AttendeeCopyWithImpl(this._self, this._then);

  final _Attendee _self;
  final $Res Function(_Attendee) _then;

/// Create a copy of Attendee
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? email = null,Object? status = null,Object? registrationDate = null,Object? phone = freezed,}) {
  return _then(_Attendee(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,registrationDate: null == registrationDate ? _self.registrationDate : registrationDate // ignore: cast_nullable_to_non_nullable
as DateTime,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$EventStats {

 int get totalEvents; int get totalAttendees; int get checkedIn; double get revenue; double get averageAttendance;
/// Create a copy of EventStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EventStatsCopyWith<EventStats> get copyWith => _$EventStatsCopyWithImpl<EventStats>(this as EventStats, _$identity);

  /// Serializes this EventStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EventStats&&(identical(other.totalEvents, totalEvents) || other.totalEvents == totalEvents)&&(identical(other.totalAttendees, totalAttendees) || other.totalAttendees == totalAttendees)&&(identical(other.checkedIn, checkedIn) || other.checkedIn == checkedIn)&&(identical(other.revenue, revenue) || other.revenue == revenue)&&(identical(other.averageAttendance, averageAttendance) || other.averageAttendance == averageAttendance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalEvents,totalAttendees,checkedIn,revenue,averageAttendance);

@override
String toString() {
  return 'EventStats(totalEvents: $totalEvents, totalAttendees: $totalAttendees, checkedIn: $checkedIn, revenue: $revenue, averageAttendance: $averageAttendance)';
}


}

/// @nodoc
abstract mixin class $EventStatsCopyWith<$Res>  {
  factory $EventStatsCopyWith(EventStats value, $Res Function(EventStats) _then) = _$EventStatsCopyWithImpl;
@useResult
$Res call({
 int totalEvents, int totalAttendees, int checkedIn, double revenue, double averageAttendance
});




}
/// @nodoc
class _$EventStatsCopyWithImpl<$Res>
    implements $EventStatsCopyWith<$Res> {
  _$EventStatsCopyWithImpl(this._self, this._then);

  final EventStats _self;
  final $Res Function(EventStats) _then;

/// Create a copy of EventStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalEvents = null,Object? totalAttendees = null,Object? checkedIn = null,Object? revenue = null,Object? averageAttendance = null,}) {
  return _then(_self.copyWith(
totalEvents: null == totalEvents ? _self.totalEvents : totalEvents // ignore: cast_nullable_to_non_nullable
as int,totalAttendees: null == totalAttendees ? _self.totalAttendees : totalAttendees // ignore: cast_nullable_to_non_nullable
as int,checkedIn: null == checkedIn ? _self.checkedIn : checkedIn // ignore: cast_nullable_to_non_nullable
as int,revenue: null == revenue ? _self.revenue : revenue // ignore: cast_nullable_to_non_nullable
as double,averageAttendance: null == averageAttendance ? _self.averageAttendance : averageAttendance // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [EventStats].
extension EventStatsPatterns on EventStats {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EventStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EventStats() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EventStats value)  $default,){
final _that = this;
switch (_that) {
case _EventStats():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EventStats value)?  $default,){
final _that = this;
switch (_that) {
case _EventStats() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalEvents,  int totalAttendees,  int checkedIn,  double revenue,  double averageAttendance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EventStats() when $default != null:
return $default(_that.totalEvents,_that.totalAttendees,_that.checkedIn,_that.revenue,_that.averageAttendance);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalEvents,  int totalAttendees,  int checkedIn,  double revenue,  double averageAttendance)  $default,) {final _that = this;
switch (_that) {
case _EventStats():
return $default(_that.totalEvents,_that.totalAttendees,_that.checkedIn,_that.revenue,_that.averageAttendance);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalEvents,  int totalAttendees,  int checkedIn,  double revenue,  double averageAttendance)?  $default,) {final _that = this;
switch (_that) {
case _EventStats() when $default != null:
return $default(_that.totalEvents,_that.totalAttendees,_that.checkedIn,_that.revenue,_that.averageAttendance);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EventStats implements EventStats {
  const _EventStats({required this.totalEvents, required this.totalAttendees, required this.checkedIn, required this.revenue, required this.averageAttendance});
  factory _EventStats.fromJson(Map<String, dynamic> json) => _$EventStatsFromJson(json);

@override final  int totalEvents;
@override final  int totalAttendees;
@override final  int checkedIn;
@override final  double revenue;
@override final  double averageAttendance;

/// Create a copy of EventStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EventStatsCopyWith<_EventStats> get copyWith => __$EventStatsCopyWithImpl<_EventStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EventStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EventStats&&(identical(other.totalEvents, totalEvents) || other.totalEvents == totalEvents)&&(identical(other.totalAttendees, totalAttendees) || other.totalAttendees == totalAttendees)&&(identical(other.checkedIn, checkedIn) || other.checkedIn == checkedIn)&&(identical(other.revenue, revenue) || other.revenue == revenue)&&(identical(other.averageAttendance, averageAttendance) || other.averageAttendance == averageAttendance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalEvents,totalAttendees,checkedIn,revenue,averageAttendance);

@override
String toString() {
  return 'EventStats(totalEvents: $totalEvents, totalAttendees: $totalAttendees, checkedIn: $checkedIn, revenue: $revenue, averageAttendance: $averageAttendance)';
}


}

/// @nodoc
abstract mixin class _$EventStatsCopyWith<$Res> implements $EventStatsCopyWith<$Res> {
  factory _$EventStatsCopyWith(_EventStats value, $Res Function(_EventStats) _then) = __$EventStatsCopyWithImpl;
@override @useResult
$Res call({
 int totalEvents, int totalAttendees, int checkedIn, double revenue, double averageAttendance
});




}
/// @nodoc
class __$EventStatsCopyWithImpl<$Res>
    implements _$EventStatsCopyWith<$Res> {
  __$EventStatsCopyWithImpl(this._self, this._then);

  final _EventStats _self;
  final $Res Function(_EventStats) _then;

/// Create a copy of EventStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalEvents = null,Object? totalAttendees = null,Object? checkedIn = null,Object? revenue = null,Object? averageAttendance = null,}) {
  return _then(_EventStats(
totalEvents: null == totalEvents ? _self.totalEvents : totalEvents // ignore: cast_nullable_to_non_nullable
as int,totalAttendees: null == totalAttendees ? _self.totalAttendees : totalAttendees // ignore: cast_nullable_to_non_nullable
as int,checkedIn: null == checkedIn ? _self.checkedIn : checkedIn // ignore: cast_nullable_to_non_nullable
as int,revenue: null == revenue ? _self.revenue : revenue // ignore: cast_nullable_to_non_nullable
as double,averageAttendance: null == averageAttendance ? _self.averageAttendance : averageAttendance // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on

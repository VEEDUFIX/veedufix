// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'booking_otp_api.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookingOtpInfo {

 String get bookingId; String get otp; DateTime? get otpExpiresAt;
/// Create a copy of BookingOtpInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingOtpInfoCopyWith<BookingOtpInfo> get copyWith => _$BookingOtpInfoCopyWithImpl<BookingOtpInfo>(this as BookingOtpInfo, _$identity);

  /// Serializes this BookingOtpInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookingOtpInfo&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.otp, otp) || other.otp == otp)&&(identical(other.otpExpiresAt, otpExpiresAt) || other.otpExpiresAt == otpExpiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bookingId,otp,otpExpiresAt);

@override
String toString() {
  return 'BookingOtpInfo(bookingId: $bookingId, otp: $otp, otpExpiresAt: $otpExpiresAt)';
}


}

/// @nodoc
abstract mixin class $BookingOtpInfoCopyWith<$Res>  {
  factory $BookingOtpInfoCopyWith(BookingOtpInfo value, $Res Function(BookingOtpInfo) _then) = _$BookingOtpInfoCopyWithImpl;
@useResult
$Res call({
 String bookingId, String otp, DateTime? otpExpiresAt
});




}
/// @nodoc
class _$BookingOtpInfoCopyWithImpl<$Res>
    implements $BookingOtpInfoCopyWith<$Res> {
  _$BookingOtpInfoCopyWithImpl(this._self, this._then);

  final BookingOtpInfo _self;
  final $Res Function(BookingOtpInfo) _then;

/// Create a copy of BookingOtpInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bookingId = null,Object? otp = null,Object? otpExpiresAt = freezed,}) {
  return _then(_self.copyWith(
bookingId: null == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String,otp: null == otp ? _self.otp : otp // ignore: cast_nullable_to_non_nullable
as String,otpExpiresAt: freezed == otpExpiresAt ? _self.otpExpiresAt : otpExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [BookingOtpInfo].
extension BookingOtpInfoPatterns on BookingOtpInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookingOtpInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookingOtpInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookingOtpInfo value)  $default,){
final _that = this;
switch (_that) {
case _BookingOtpInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookingOtpInfo value)?  $default,){
final _that = this;
switch (_that) {
case _BookingOtpInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String bookingId,  String otp,  DateTime? otpExpiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookingOtpInfo() when $default != null:
return $default(_that.bookingId,_that.otp,_that.otpExpiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String bookingId,  String otp,  DateTime? otpExpiresAt)  $default,) {final _that = this;
switch (_that) {
case _BookingOtpInfo():
return $default(_that.bookingId,_that.otp,_that.otpExpiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String bookingId,  String otp,  DateTime? otpExpiresAt)?  $default,) {final _that = this;
switch (_that) {
case _BookingOtpInfo() when $default != null:
return $default(_that.bookingId,_that.otp,_that.otpExpiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookingOtpInfo extends BookingOtpInfo {
  const _BookingOtpInfo({this.bookingId = '', this.otp = '', this.otpExpiresAt}): super._();
  factory _BookingOtpInfo.fromJson(Map<String, dynamic> json) => _$BookingOtpInfoFromJson(json);

@override@JsonKey() final  String bookingId;
@override@JsonKey() final  String otp;
@override final  DateTime? otpExpiresAt;

/// Create a copy of BookingOtpInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingOtpInfoCopyWith<_BookingOtpInfo> get copyWith => __$BookingOtpInfoCopyWithImpl<_BookingOtpInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookingOtpInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookingOtpInfo&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.otp, otp) || other.otp == otp)&&(identical(other.otpExpiresAt, otpExpiresAt) || other.otpExpiresAt == otpExpiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bookingId,otp,otpExpiresAt);

@override
String toString() {
  return 'BookingOtpInfo(bookingId: $bookingId, otp: $otp, otpExpiresAt: $otpExpiresAt)';
}


}

/// @nodoc
abstract mixin class _$BookingOtpInfoCopyWith<$Res> implements $BookingOtpInfoCopyWith<$Res> {
  factory _$BookingOtpInfoCopyWith(_BookingOtpInfo value, $Res Function(_BookingOtpInfo) _then) = __$BookingOtpInfoCopyWithImpl;
@override @useResult
$Res call({
 String bookingId, String otp, DateTime? otpExpiresAt
});




}
/// @nodoc
class __$BookingOtpInfoCopyWithImpl<$Res>
    implements _$BookingOtpInfoCopyWith<$Res> {
  __$BookingOtpInfoCopyWithImpl(this._self, this._then);

  final _BookingOtpInfo _self;
  final $Res Function(_BookingOtpInfo) _then;

/// Create a copy of BookingOtpInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bookingId = null,Object? otp = null,Object? otpExpiresAt = freezed,}) {
  return _then(_BookingOtpInfo(
bookingId: null == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String,otp: null == otp ? _self.otp : otp // ignore: cast_nullable_to_non_nullable
as String,otpExpiresAt: freezed == otpExpiresAt ? _self.otpExpiresAt : otpExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$BookingOtpDetails {

 String get bookingId; String get bookingCode; String get serviceName; String get customerName; String get workerName; String? get workerPhotoUrl; String? get locationLabel; String? get statusLabel; List<String> get afterPhotoUrls;
/// Create a copy of BookingOtpDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingOtpDetailsCopyWith<BookingOtpDetails> get copyWith => _$BookingOtpDetailsCopyWithImpl<BookingOtpDetails>(this as BookingOtpDetails, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookingOtpDetails&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.bookingCode, bookingCode) || other.bookingCode == bookingCode)&&(identical(other.serviceName, serviceName) || other.serviceName == serviceName)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.workerName, workerName) || other.workerName == workerName)&&(identical(other.workerPhotoUrl, workerPhotoUrl) || other.workerPhotoUrl == workerPhotoUrl)&&(identical(other.locationLabel, locationLabel) || other.locationLabel == locationLabel)&&(identical(other.statusLabel, statusLabel) || other.statusLabel == statusLabel)&&const DeepCollectionEquality().equals(other.afterPhotoUrls, afterPhotoUrls));
}


@override
int get hashCode => Object.hash(runtimeType,bookingId,bookingCode,serviceName,customerName,workerName,workerPhotoUrl,locationLabel,statusLabel,const DeepCollectionEquality().hash(afterPhotoUrls));

@override
String toString() {
  return 'BookingOtpDetails(bookingId: $bookingId, bookingCode: $bookingCode, serviceName: $serviceName, customerName: $customerName, workerName: $workerName, workerPhotoUrl: $workerPhotoUrl, locationLabel: $locationLabel, statusLabel: $statusLabel, afterPhotoUrls: $afterPhotoUrls)';
}


}

/// @nodoc
abstract mixin class $BookingOtpDetailsCopyWith<$Res>  {
  factory $BookingOtpDetailsCopyWith(BookingOtpDetails value, $Res Function(BookingOtpDetails) _then) = _$BookingOtpDetailsCopyWithImpl;
@useResult
$Res call({
 String bookingId, String bookingCode, String serviceName, String customerName, String workerName, String? workerPhotoUrl, String? locationLabel, String? statusLabel, List<String> afterPhotoUrls
});




}
/// @nodoc
class _$BookingOtpDetailsCopyWithImpl<$Res>
    implements $BookingOtpDetailsCopyWith<$Res> {
  _$BookingOtpDetailsCopyWithImpl(this._self, this._then);

  final BookingOtpDetails _self;
  final $Res Function(BookingOtpDetails) _then;

/// Create a copy of BookingOtpDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bookingId = null,Object? bookingCode = null,Object? serviceName = null,Object? customerName = null,Object? workerName = null,Object? workerPhotoUrl = freezed,Object? locationLabel = freezed,Object? statusLabel = freezed,Object? afterPhotoUrls = null,}) {
  return _then(_self.copyWith(
bookingId: null == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String,bookingCode: null == bookingCode ? _self.bookingCode : bookingCode // ignore: cast_nullable_to_non_nullable
as String,serviceName: null == serviceName ? _self.serviceName : serviceName // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,workerName: null == workerName ? _self.workerName : workerName // ignore: cast_nullable_to_non_nullable
as String,workerPhotoUrl: freezed == workerPhotoUrl ? _self.workerPhotoUrl : workerPhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,locationLabel: freezed == locationLabel ? _self.locationLabel : locationLabel // ignore: cast_nullable_to_non_nullable
as String?,statusLabel: freezed == statusLabel ? _self.statusLabel : statusLabel // ignore: cast_nullable_to_non_nullable
as String?,afterPhotoUrls: null == afterPhotoUrls ? _self.afterPhotoUrls : afterPhotoUrls // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [BookingOtpDetails].
extension BookingOtpDetailsPatterns on BookingOtpDetails {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookingOtpDetails value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookingOtpDetails() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookingOtpDetails value)  $default,){
final _that = this;
switch (_that) {
case _BookingOtpDetails():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookingOtpDetails value)?  $default,){
final _that = this;
switch (_that) {
case _BookingOtpDetails() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String bookingId,  String bookingCode,  String serviceName,  String customerName,  String workerName,  String? workerPhotoUrl,  String? locationLabel,  String? statusLabel,  List<String> afterPhotoUrls)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookingOtpDetails() when $default != null:
return $default(_that.bookingId,_that.bookingCode,_that.serviceName,_that.customerName,_that.workerName,_that.workerPhotoUrl,_that.locationLabel,_that.statusLabel,_that.afterPhotoUrls);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String bookingId,  String bookingCode,  String serviceName,  String customerName,  String workerName,  String? workerPhotoUrl,  String? locationLabel,  String? statusLabel,  List<String> afterPhotoUrls)  $default,) {final _that = this;
switch (_that) {
case _BookingOtpDetails():
return $default(_that.bookingId,_that.bookingCode,_that.serviceName,_that.customerName,_that.workerName,_that.workerPhotoUrl,_that.locationLabel,_that.statusLabel,_that.afterPhotoUrls);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String bookingId,  String bookingCode,  String serviceName,  String customerName,  String workerName,  String? workerPhotoUrl,  String? locationLabel,  String? statusLabel,  List<String> afterPhotoUrls)?  $default,) {final _that = this;
switch (_that) {
case _BookingOtpDetails() when $default != null:
return $default(_that.bookingId,_that.bookingCode,_that.serviceName,_that.customerName,_that.workerName,_that.workerPhotoUrl,_that.locationLabel,_that.statusLabel,_that.afterPhotoUrls);case _:
  return null;

}
}

}

/// @nodoc


class _BookingOtpDetails extends BookingOtpDetails {
  const _BookingOtpDetails({this.bookingId = '', this.bookingCode = '', this.serviceName = 'Service booking', this.customerName = 'Customer', this.workerName = 'Your professional', this.workerPhotoUrl, this.locationLabel, this.statusLabel, final  List<String> afterPhotoUrls = const <String>[]}): _afterPhotoUrls = afterPhotoUrls,super._();
  

@override@JsonKey() final  String bookingId;
@override@JsonKey() final  String bookingCode;
@override@JsonKey() final  String serviceName;
@override@JsonKey() final  String customerName;
@override@JsonKey() final  String workerName;
@override final  String? workerPhotoUrl;
@override final  String? locationLabel;
@override final  String? statusLabel;
 final  List<String> _afterPhotoUrls;
@override@JsonKey() List<String> get afterPhotoUrls {
  if (_afterPhotoUrls is EqualUnmodifiableListView) return _afterPhotoUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_afterPhotoUrls);
}


/// Create a copy of BookingOtpDetails
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingOtpDetailsCopyWith<_BookingOtpDetails> get copyWith => __$BookingOtpDetailsCopyWithImpl<_BookingOtpDetails>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookingOtpDetails&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.bookingCode, bookingCode) || other.bookingCode == bookingCode)&&(identical(other.serviceName, serviceName) || other.serviceName == serviceName)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.workerName, workerName) || other.workerName == workerName)&&(identical(other.workerPhotoUrl, workerPhotoUrl) || other.workerPhotoUrl == workerPhotoUrl)&&(identical(other.locationLabel, locationLabel) || other.locationLabel == locationLabel)&&(identical(other.statusLabel, statusLabel) || other.statusLabel == statusLabel)&&const DeepCollectionEquality().equals(other._afterPhotoUrls, _afterPhotoUrls));
}


@override
int get hashCode => Object.hash(runtimeType,bookingId,bookingCode,serviceName,customerName,workerName,workerPhotoUrl,locationLabel,statusLabel,const DeepCollectionEquality().hash(_afterPhotoUrls));

@override
String toString() {
  return 'BookingOtpDetails(bookingId: $bookingId, bookingCode: $bookingCode, serviceName: $serviceName, customerName: $customerName, workerName: $workerName, workerPhotoUrl: $workerPhotoUrl, locationLabel: $locationLabel, statusLabel: $statusLabel, afterPhotoUrls: $afterPhotoUrls)';
}


}

/// @nodoc
abstract mixin class _$BookingOtpDetailsCopyWith<$Res> implements $BookingOtpDetailsCopyWith<$Res> {
  factory _$BookingOtpDetailsCopyWith(_BookingOtpDetails value, $Res Function(_BookingOtpDetails) _then) = __$BookingOtpDetailsCopyWithImpl;
@override @useResult
$Res call({
 String bookingId, String bookingCode, String serviceName, String customerName, String workerName, String? workerPhotoUrl, String? locationLabel, String? statusLabel, List<String> afterPhotoUrls
});




}
/// @nodoc
class __$BookingOtpDetailsCopyWithImpl<$Res>
    implements _$BookingOtpDetailsCopyWith<$Res> {
  __$BookingOtpDetailsCopyWithImpl(this._self, this._then);

  final _BookingOtpDetails _self;
  final $Res Function(_BookingOtpDetails) _then;

/// Create a copy of BookingOtpDetails
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bookingId = null,Object? bookingCode = null,Object? serviceName = null,Object? customerName = null,Object? workerName = null,Object? workerPhotoUrl = freezed,Object? locationLabel = freezed,Object? statusLabel = freezed,Object? afterPhotoUrls = null,}) {
  return _then(_BookingOtpDetails(
bookingId: null == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String,bookingCode: null == bookingCode ? _self.bookingCode : bookingCode // ignore: cast_nullable_to_non_nullable
as String,serviceName: null == serviceName ? _self.serviceName : serviceName // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,workerName: null == workerName ? _self.workerName : workerName // ignore: cast_nullable_to_non_nullable
as String,workerPhotoUrl: freezed == workerPhotoUrl ? _self.workerPhotoUrl : workerPhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,locationLabel: freezed == locationLabel ? _self.locationLabel : locationLabel // ignore: cast_nullable_to_non_nullable
as String?,statusLabel: freezed == statusLabel ? _self.statusLabel : statusLabel // ignore: cast_nullable_to_non_nullable
as String?,afterPhotoUrls: null == afterPhotoUrls ? _self._afterPhotoUrls : afterPhotoUrls // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invite_code.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InviteCode {

 String get code; String get companyId; DateTime get createdAt; DateTime? get expiresAt; bool get isUsed;
/// Create a copy of InviteCode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InviteCodeCopyWith<InviteCode> get copyWith => _$InviteCodeCopyWithImpl<InviteCode>(this as InviteCode, _$identity);

  /// Serializes this InviteCode to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as InviteCode;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InviteCode&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.companyId, _this.companyId) || other.companyId == _this.companyId)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.isUsed, _this.isUsed) || other.isUsed == _this.isUsed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as InviteCode;
  return Object.hash(runtimeType,_this.code,_this.companyId,_this.createdAt,_this.expiresAt,_this.isUsed);
}

@override
String toString() {
  final _this = this as InviteCode;
  return 'InviteCode(code: ${_this.code}, companyId: ${_this.companyId}, createdAt: ${_this.createdAt}, expiresAt: ${_this.expiresAt}, isUsed: ${_this.isUsed})';
}


}

/// @nodoc
abstract mixin class $InviteCodeCopyWith<$Res>  {
  factory $InviteCodeCopyWith(InviteCode value, $Res Function(InviteCode) _then) = _$InviteCodeCopyWithImpl;
@useResult
$Res call({
 String code, String companyId, DateTime createdAt, DateTime? expiresAt, bool isUsed
});




}
/// @nodoc
class _$InviteCodeCopyWithImpl<$Res>
    implements $InviteCodeCopyWith<$Res> {
  _$InviteCodeCopyWithImpl(this._self, this._then);

  final InviteCode _self;
  final $Res Function(InviteCode) _then;

/// Create a copy of InviteCode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? companyId = null,Object? createdAt = null,Object? expiresAt = freezed,Object? isUsed = null,}) {
  return _then(InviteCode(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isUsed: null == isUsed ? _self.isUsed : isUsed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [InviteCode].
extension InviteCodePatterns on InviteCode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InviteCode value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InviteCode() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InviteCode value)  $default,){
final _that = this;
switch (_that) {
case _InviteCode():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InviteCode value)?  $default,){
final _that = this;
switch (_that) {
case _InviteCode() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String companyId,  DateTime createdAt,  DateTime? expiresAt,  bool isUsed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InviteCode() when $default != null:
return $default(_that.code,_that.companyId,_that.createdAt,_that.expiresAt,_that.isUsed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String companyId,  DateTime createdAt,  DateTime? expiresAt,  bool isUsed)  $default,) {final _that = this;
switch (_that) {
case _InviteCode():
return $default(_that.code,_that.companyId,_that.createdAt,_that.expiresAt,_that.isUsed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String companyId,  DateTime createdAt,  DateTime? expiresAt,  bool isUsed)?  $default,) {final _that = this;
switch (_that) {
case _InviteCode() when $default != null:
return $default(_that.code,_that.companyId,_that.createdAt,_that.expiresAt,_that.isUsed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InviteCode implements InviteCode {
  const _InviteCode({required this.code, required this.companyId, required this.createdAt, this.expiresAt, this.isUsed = false});
  factory _InviteCode.fromJson(Map<String, dynamic> json) => _$InviteCodeFromJson(json);

@override final  String code;
@override final  String companyId;
@override final  DateTime createdAt;
@override final  DateTime? expiresAt;
@override@JsonKey() final  bool isUsed;

/// Create a copy of InviteCode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InviteCodeCopyWith<_InviteCode> get copyWith => __$InviteCodeCopyWithImpl<_InviteCode>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InviteCodeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InviteCode&&(identical(other.code, code) || other.code == code)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.isUsed, isUsed) || other.isUsed == isUsed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,companyId,createdAt,expiresAt,isUsed);
}

@override
String toString() {
    return 'InviteCode(code: $code, companyId: $companyId, createdAt: $createdAt, expiresAt: $expiresAt, isUsed: $isUsed)';
}


}

/// @nodoc
abstract mixin class _$InviteCodeCopyWith<$Res> implements $InviteCodeCopyWith<$Res> {
  factory _$InviteCodeCopyWith(_InviteCode value, $Res Function(_InviteCode) _then) = __$InviteCodeCopyWithImpl;
@override @useResult
$Res call({
 String code, String companyId, DateTime createdAt, DateTime? expiresAt, bool isUsed
});




}
/// @nodoc
class __$InviteCodeCopyWithImpl<$Res>
    implements _$InviteCodeCopyWith<$Res> {
  __$InviteCodeCopyWithImpl(this._self, this._then);

  final _InviteCode _self;
  final $Res Function(_InviteCode) _then;

/// Create a copy of InviteCode
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? companyId = null,Object? createdAt = null,Object? expiresAt = freezed,Object? isUsed = null,}) {
  return _then(_InviteCode(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isUsed: null == isUsed ? _self.isUsed : isUsed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on

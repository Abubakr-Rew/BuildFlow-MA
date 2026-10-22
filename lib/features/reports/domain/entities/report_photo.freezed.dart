// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'report_photo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReportPhoto {

 String get id;/// URL or local path. Fake photos use 'fake:N' scheme.
 String get url; String? get thumbnailUrl;
/// Create a copy of ReportPhoto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReportPhotoCopyWith<ReportPhoto> get copyWith => _$ReportPhotoCopyWithImpl<ReportPhoto>(this as ReportPhoto, _$identity);

  /// Serializes this ReportPhoto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReportPhoto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReportPhoto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.thumbnailUrl, _this.thumbnailUrl) || other.thumbnailUrl == _this.thumbnailUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReportPhoto;
  return Object.hash(runtimeType,_this.id,_this.url,_this.thumbnailUrl);
}

@override
String toString() {
  final _this = this as ReportPhoto;
  return 'ReportPhoto(id: ${_this.id}, url: ${_this.url}, thumbnailUrl: ${_this.thumbnailUrl})';
}


}

/// @nodoc
abstract mixin class $ReportPhotoCopyWith<$Res>  {
  factory $ReportPhotoCopyWith(ReportPhoto value, $Res Function(ReportPhoto) _then) = _$ReportPhotoCopyWithImpl;
@useResult
$Res call({
 String id, String url, String? thumbnailUrl
});




}
/// @nodoc
class _$ReportPhotoCopyWithImpl<$Res>
    implements $ReportPhotoCopyWith<$Res> {
  _$ReportPhotoCopyWithImpl(this._self, this._then);

  final ReportPhoto _self;
  final $Res Function(ReportPhoto) _then;

/// Create a copy of ReportPhoto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? url = null,Object? thumbnailUrl = freezed,}) {
  return _then(ReportPhoto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReportPhoto].
extension ReportPhotoPatterns on ReportPhoto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReportPhoto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReportPhoto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReportPhoto value)  $default,){
final _that = this;
switch (_that) {
case _ReportPhoto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReportPhoto value)?  $default,){
final _that = this;
switch (_that) {
case _ReportPhoto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String url,  String? thumbnailUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReportPhoto() when $default != null:
return $default(_that.id,_that.url,_that.thumbnailUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String url,  String? thumbnailUrl)  $default,) {final _that = this;
switch (_that) {
case _ReportPhoto():
return $default(_that.id,_that.url,_that.thumbnailUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String url,  String? thumbnailUrl)?  $default,) {final _that = this;
switch (_that) {
case _ReportPhoto() when $default != null:
return $default(_that.id,_that.url,_that.thumbnailUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReportPhoto implements ReportPhoto {
  const _ReportPhoto({required this.id, required this.url, this.thumbnailUrl});
  factory _ReportPhoto.fromJson(Map<String, dynamic> json) => _$ReportPhotoFromJson(json);

@override final  String id;
/// URL or local path. Fake photos use 'fake:N' scheme.
@override final  String url;
@override final  String? thumbnailUrl;

/// Create a copy of ReportPhoto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReportPhotoCopyWith<_ReportPhoto> get copyWith => __$ReportPhotoCopyWithImpl<_ReportPhoto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReportPhotoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReportPhoto&&(identical(other.id, id) || other.id == id)&&(identical(other.url, url) || other.url == url)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,url,thumbnailUrl);
}

@override
String toString() {
    return 'ReportPhoto(id: $id, url: $url, thumbnailUrl: $thumbnailUrl)';
}


}

/// @nodoc
abstract mixin class _$ReportPhotoCopyWith<$Res> implements $ReportPhotoCopyWith<$Res> {
  factory _$ReportPhotoCopyWith(_ReportPhoto value, $Res Function(_ReportPhoto) _then) = __$ReportPhotoCopyWithImpl;
@override @useResult
$Res call({
 String id, String url, String? thumbnailUrl
});




}
/// @nodoc
class __$ReportPhotoCopyWithImpl<$Res>
    implements _$ReportPhotoCopyWith<$Res> {
  __$ReportPhotoCopyWithImpl(this._self, this._then);

  final _ReportPhoto _self;
  final $Res Function(_ReportPhoto) _then;

/// Create a copy of ReportPhoto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? url = null,Object? thumbnailUrl = freezed,}) {
  return _then(_ReportPhoto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'report.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Report {

 String get id; String get projectId; String get projectName; String get authorId; String get authorName; String get text; List<ReportPhoto> get photos; DateTime get createdAt;
/// Create a copy of Report
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReportCopyWith<Report> get copyWith => _$ReportCopyWithImpl<Report>(this as Report, _$identity);

  /// Serializes this Report to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Report;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Report&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.projectId, _this.projectId) || other.projectId == _this.projectId)&&(identical(other.projectName, _this.projectName) || other.projectName == _this.projectName)&&(identical(other.authorId, _this.authorId) || other.authorId == _this.authorId)&&(identical(other.authorName, _this.authorName) || other.authorName == _this.authorName)&&(identical(other.text, _this.text) || other.text == _this.text)&&const DeepCollectionEquality().equals(other.photos, _this.photos)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Report;
  return Object.hash(runtimeType,_this.id,_this.projectId,_this.projectName,_this.authorId,_this.authorName,_this.text,const DeepCollectionEquality().hash(_this.photos),_this.createdAt);
}

@override
String toString() {
  final _this = this as Report;
  return 'Report(id: ${_this.id}, projectId: ${_this.projectId}, projectName: ${_this.projectName}, authorId: ${_this.authorId}, authorName: ${_this.authorName}, text: ${_this.text}, photos: ${_this.photos}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $ReportCopyWith<$Res>  {
  factory $ReportCopyWith(Report value, $Res Function(Report) _then) = _$ReportCopyWithImpl;
@useResult
$Res call({
 String id, String projectId, String projectName, String authorId, String authorName, String text, List<ReportPhoto> photos, DateTime createdAt
});




}
/// @nodoc
class _$ReportCopyWithImpl<$Res>
    implements $ReportCopyWith<$Res> {
  _$ReportCopyWithImpl(this._self, this._then);

  final Report _self;
  final $Res Function(Report) _then;

/// Create a copy of Report
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? projectId = null,Object? projectName = null,Object? authorId = null,Object? authorName = null,Object? text = null,Object? photos = null,Object? createdAt = null,}) {
  return _then(Report(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,projectName: null == projectName ? _self.projectName : projectName // ignore: cast_nullable_to_non_nullable
as String,authorId: null == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String,authorName: null == authorName ? _self.authorName : authorName // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as List<ReportPhoto>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Report].
extension ReportPatterns on Report {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Report value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Report() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Report value)  $default,){
final _that = this;
switch (_that) {
case _Report():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Report value)?  $default,){
final _that = this;
switch (_that) {
case _Report() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String projectId,  String projectName,  String authorId,  String authorName,  String text,  List<ReportPhoto> photos,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Report() when $default != null:
return $default(_that.id,_that.projectId,_that.projectName,_that.authorId,_that.authorName,_that.text,_that.photos,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String projectId,  String projectName,  String authorId,  String authorName,  String text,  List<ReportPhoto> photos,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Report():
return $default(_that.id,_that.projectId,_that.projectName,_that.authorId,_that.authorName,_that.text,_that.photos,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String projectId,  String projectName,  String authorId,  String authorName,  String text,  List<ReportPhoto> photos,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Report() when $default != null:
return $default(_that.id,_that.projectId,_that.projectName,_that.authorId,_that.authorName,_that.text,_that.photos,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Report implements Report {
  const _Report({required this.id, required this.projectId, required this.projectName, required this.authorId, required this.authorName, required this.text, required  List<ReportPhoto> photos, required this.createdAt}): _photos = photos;
  factory _Report.fromJson(Map<String, dynamic> json) => _$ReportFromJson(json);

@override final  String id;
@override final  String projectId;
@override final  String projectName;
@override final  String authorId;
@override final  String authorName;
@override final  String text;
 final  List<ReportPhoto> _photos;
@override List<ReportPhoto> get photos {
  if (_photos is EqualUnmodifiableListView) return _photos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photos);
}

@override final  DateTime createdAt;

/// Create a copy of Report
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReportCopyWith<_Report> get copyWith => __$ReportCopyWithImpl<_Report>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReportToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Report&&(identical(other.id, id) || other.id == id)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.projectName, projectName) || other.projectName == projectName)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.authorName, authorName) || other.authorName == authorName)&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other.photos, _photos)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,projectId,projectName,authorId,authorName,text,const DeepCollectionEquality().hash(_photos),createdAt);
}

@override
String toString() {
    return 'Report(id: $id, projectId: $projectId, projectName: $projectName, authorId: $authorId, authorName: $authorName, text: $text, photos: $photos, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ReportCopyWith<$Res> implements $ReportCopyWith<$Res> {
  factory _$ReportCopyWith(_Report value, $Res Function(_Report) _then) = __$ReportCopyWithImpl;
@override @useResult
$Res call({
 String id, String projectId, String projectName, String authorId, String authorName, String text, List<ReportPhoto> photos, DateTime createdAt
});




}
/// @nodoc
class __$ReportCopyWithImpl<$Res>
    implements _$ReportCopyWith<$Res> {
  __$ReportCopyWithImpl(this._self, this._then);

  final _Report _self;
  final $Res Function(_Report) _then;

/// Create a copy of Report
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? projectId = null,Object? projectName = null,Object? authorId = null,Object? authorName = null,Object? text = null,Object? photos = null,Object? createdAt = null,}) {
  return _then(_Report(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,projectName: null == projectName ? _self.projectName : projectName // ignore: cast_nullable_to_non_nullable
as String,authorId: null == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String,authorName: null == authorName ? _self.authorName : authorName // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,photos: null == photos ? _self._photos : photos // ignore: cast_nullable_to_non_nullable
as List<ReportPhoto>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on

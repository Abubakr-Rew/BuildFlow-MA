// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'draft_report.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DraftReport {

 String get id; String get projectId; String get projectName; String get text; List<String> get photoPaths; DateTime get createdAt;
/// Create a copy of DraftReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DraftReportCopyWith<DraftReport> get copyWith => _$DraftReportCopyWithImpl<DraftReport>(this as DraftReport, _$identity);

  /// Serializes this DraftReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DraftReport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DraftReport&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.projectId, _this.projectId) || other.projectId == _this.projectId)&&(identical(other.projectName, _this.projectName) || other.projectName == _this.projectName)&&(identical(other.text, _this.text) || other.text == _this.text)&&const DeepCollectionEquality().equals(other.photoPaths, _this.photoPaths)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DraftReport;
  return Object.hash(runtimeType,_this.id,_this.projectId,_this.projectName,_this.text,const DeepCollectionEquality().hash(_this.photoPaths),_this.createdAt);
}

@override
String toString() {
  final _this = this as DraftReport;
  return 'DraftReport(id: ${_this.id}, projectId: ${_this.projectId}, projectName: ${_this.projectName}, text: ${_this.text}, photoPaths: ${_this.photoPaths}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $DraftReportCopyWith<$Res>  {
  factory $DraftReportCopyWith(DraftReport value, $Res Function(DraftReport) _then) = _$DraftReportCopyWithImpl;
@useResult
$Res call({
 String id, String projectId, String projectName, String text, List<String> photoPaths, DateTime createdAt
});




}
/// @nodoc
class _$DraftReportCopyWithImpl<$Res>
    implements $DraftReportCopyWith<$Res> {
  _$DraftReportCopyWithImpl(this._self, this._then);

  final DraftReport _self;
  final $Res Function(DraftReport) _then;

/// Create a copy of DraftReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? projectId = null,Object? projectName = null,Object? text = null,Object? photoPaths = null,Object? createdAt = null,}) {
  return _then(DraftReport(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,projectName: null == projectName ? _self.projectName : projectName // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,photoPaths: null == photoPaths ? _self.photoPaths : photoPaths // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [DraftReport].
extension DraftReportPatterns on DraftReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DraftReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DraftReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DraftReport value)  $default,){
final _that = this;
switch (_that) {
case _DraftReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DraftReport value)?  $default,){
final _that = this;
switch (_that) {
case _DraftReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String projectId,  String projectName,  String text,  List<String> photoPaths,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DraftReport() when $default != null:
return $default(_that.id,_that.projectId,_that.projectName,_that.text,_that.photoPaths,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String projectId,  String projectName,  String text,  List<String> photoPaths,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _DraftReport():
return $default(_that.id,_that.projectId,_that.projectName,_that.text,_that.photoPaths,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String projectId,  String projectName,  String text,  List<String> photoPaths,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _DraftReport() when $default != null:
return $default(_that.id,_that.projectId,_that.projectName,_that.text,_that.photoPaths,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DraftReport implements DraftReport {
  const _DraftReport({required this.id, required this.projectId, required this.projectName, required this.text, required  List<String> photoPaths, required this.createdAt}): _photoPaths = photoPaths;
  factory _DraftReport.fromJson(Map<String, dynamic> json) => _$DraftReportFromJson(json);

@override final  String id;
@override final  String projectId;
@override final  String projectName;
@override final  String text;
 final  List<String> _photoPaths;
@override List<String> get photoPaths {
  if (_photoPaths is EqualUnmodifiableListView) return _photoPaths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photoPaths);
}

@override final  DateTime createdAt;

/// Create a copy of DraftReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DraftReportCopyWith<_DraftReport> get copyWith => __$DraftReportCopyWithImpl<_DraftReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DraftReportToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DraftReport&&(identical(other.id, id) || other.id == id)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.projectName, projectName) || other.projectName == projectName)&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other.photoPaths, _photoPaths)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,projectId,projectName,text,const DeepCollectionEquality().hash(_photoPaths),createdAt);
}

@override
String toString() {
    return 'DraftReport(id: $id, projectId: $projectId, projectName: $projectName, text: $text, photoPaths: $photoPaths, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$DraftReportCopyWith<$Res> implements $DraftReportCopyWith<$Res> {
  factory _$DraftReportCopyWith(_DraftReport value, $Res Function(_DraftReport) _then) = __$DraftReportCopyWithImpl;
@override @useResult
$Res call({
 String id, String projectId, String projectName, String text, List<String> photoPaths, DateTime createdAt
});




}
/// @nodoc
class __$DraftReportCopyWithImpl<$Res>
    implements _$DraftReportCopyWith<$Res> {
  __$DraftReportCopyWithImpl(this._self, this._then);

  final _DraftReport _self;
  final $Res Function(_DraftReport) _then;

/// Create a copy of DraftReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? projectId = null,Object? projectName = null,Object? text = null,Object? photoPaths = null,Object? createdAt = null,}) {
  return _then(_DraftReport(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,projectName: null == projectName ? _self.projectName : projectName // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,photoPaths: null == photoPaths ? _self._photoPaths : photoPaths // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on

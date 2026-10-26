// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Project {

 String get id; String get name; String get address; ProjectStatus get status; String get companyId; List<String> get foremanIds; List<String> get workerIds;
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectCopyWith<Project> get copyWith => _$ProjectCopyWithImpl<Project>(this as Project, _$identity);

  /// Serializes this Project to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Project;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Project&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.address, _this.address) || other.address == _this.address)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.companyId, _this.companyId) || other.companyId == _this.companyId)&&const DeepCollectionEquality().equals(other.foremanIds, _this.foremanIds)&&const DeepCollectionEquality().equals(other.workerIds, _this.workerIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Project;
  return Object.hash(runtimeType,_this.id,_this.name,_this.address,_this.status,_this.companyId,const DeepCollectionEquality().hash(_this.foremanIds),const DeepCollectionEquality().hash(_this.workerIds));
}

@override
String toString() {
  final _this = this as Project;
  return 'Project(id: ${_this.id}, name: ${_this.name}, address: ${_this.address}, status: ${_this.status}, companyId: ${_this.companyId}, foremanIds: ${_this.foremanIds}, workerIds: ${_this.workerIds})';
}


}

/// @nodoc
abstract mixin class $ProjectCopyWith<$Res>  {
  factory $ProjectCopyWith(Project value, $Res Function(Project) _then) = _$ProjectCopyWithImpl;
@useResult
$Res call({
 String id, String name, String address, ProjectStatus status, String companyId, List<String> foremanIds, List<String> workerIds
});




}
/// @nodoc
class _$ProjectCopyWithImpl<$Res>
    implements $ProjectCopyWith<$Res> {
  _$ProjectCopyWithImpl(this._self, this._then);

  final Project _self;
  final $Res Function(Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? address = null,Object? status = null,Object? companyId = null,Object? foremanIds = null,Object? workerIds = null,}) {
  return _then(Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProjectStatus,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as String,foremanIds: null == foremanIds ? _self.foremanIds : foremanIds // ignore: cast_nullable_to_non_nullable
as List<String>,workerIds: null == workerIds ? _self.workerIds : workerIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Project].
extension ProjectPatterns on Project {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Project value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Project value)  $default,){
final _that = this;
switch (_that) {
case _Project():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Project value)?  $default,){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String address,  ProjectStatus status,  String companyId,  List<String> foremanIds,  List<String> workerIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.name,_that.address,_that.status,_that.companyId,_that.foremanIds,_that.workerIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String address,  ProjectStatus status,  String companyId,  List<String> foremanIds,  List<String> workerIds)  $default,) {final _that = this;
switch (_that) {
case _Project():
return $default(_that.id,_that.name,_that.address,_that.status,_that.companyId,_that.foremanIds,_that.workerIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String address,  ProjectStatus status,  String companyId,  List<String> foremanIds,  List<String> workerIds)?  $default,) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.name,_that.address,_that.status,_that.companyId,_that.foremanIds,_that.workerIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Project implements Project {
  const _Project({required this.id, required this.name, required this.address, required this.status, required this.companyId,  List<String> foremanIds = const [],  List<String> workerIds = const []}): _foremanIds = foremanIds,_workerIds = workerIds;
  factory _Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);

@override final  String id;
@override final  String name;
@override final  String address;
@override final  ProjectStatus status;
@override final  String companyId;
 final  List<String> _foremanIds;
@override@JsonKey() List<String> get foremanIds {
  if (_foremanIds is EqualUnmodifiableListView) return _foremanIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_foremanIds);
}

 final  List<String> _workerIds;
@override@JsonKey() List<String> get workerIds {
  if (_workerIds is EqualUnmodifiableListView) return _workerIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_workerIds);
}


/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectCopyWith<_Project> get copyWith => __$ProjectCopyWithImpl<_Project>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Project&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.address, address) || other.address == address)&&(identical(other.status, status) || other.status == status)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&const DeepCollectionEquality().equals(other.foremanIds, _foremanIds)&&const DeepCollectionEquality().equals(other.workerIds, _workerIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,address,status,companyId,const DeepCollectionEquality().hash(_foremanIds),const DeepCollectionEquality().hash(_workerIds));
}

@override
String toString() {
    return 'Project(id: $id, name: $name, address: $address, status: $status, companyId: $companyId, foremanIds: $foremanIds, workerIds: $workerIds)';
}


}

/// @nodoc
abstract mixin class _$ProjectCopyWith<$Res> implements $ProjectCopyWith<$Res> {
  factory _$ProjectCopyWith(_Project value, $Res Function(_Project) _then) = __$ProjectCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String address, ProjectStatus status, String companyId, List<String> foremanIds, List<String> workerIds
});




}
/// @nodoc
class __$ProjectCopyWithImpl<$Res>
    implements _$ProjectCopyWith<$Res> {
  __$ProjectCopyWithImpl(this._self, this._then);

  final _Project _self;
  final $Res Function(_Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? address = null,Object? status = null,Object? companyId = null,Object? foremanIds = null,Object? workerIds = null,}) {
  return _then(_Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProjectStatus,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as String,foremanIds: null == foremanIds ? _self._foremanIds : foremanIds // ignore: cast_nullable_to_non_nullable
as List<String>,workerIds: null == workerIds ? _self._workerIds : workerIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on

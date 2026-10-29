// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_attachment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MessageAttachment {

 String get id; String get url;/// Photo size in pixels, for laying out before the image loads.
 int? get width; int? get height;/// Voice note length.
 int? get durationMs;/// Voice note loudness, `kVoiceWaveformBars` values 0–100, measured
/// while recording.
 List<int>? get waveform;/// Content type, e.g. `audio/mp4` for a voice note.
 String? get mime;
/// Create a copy of MessageAttachment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageAttachmentCopyWith<MessageAttachment> get copyWith => _$MessageAttachmentCopyWithImpl<MessageAttachment>(this as MessageAttachment, _$identity);

  /// Serializes this MessageAttachment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MessageAttachment;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageAttachment&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs)&&const DeepCollectionEquality().equals(other.waveform, _this.waveform)&&(identical(other.mime, _this.mime) || other.mime == _this.mime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MessageAttachment;
  return Object.hash(runtimeType,_this.id,_this.url,_this.width,_this.height,_this.durationMs,const DeepCollectionEquality().hash(_this.waveform),_this.mime);
}

@override
String toString() {
  final _this = this as MessageAttachment;
  return 'MessageAttachment(id: ${_this.id}, url: ${_this.url}, width: ${_this.width}, height: ${_this.height}, durationMs: ${_this.durationMs}, waveform: ${_this.waveform}, mime: ${_this.mime})';
}


}

/// @nodoc
abstract mixin class $MessageAttachmentCopyWith<$Res>  {
  factory $MessageAttachmentCopyWith(MessageAttachment value, $Res Function(MessageAttachment) _then) = _$MessageAttachmentCopyWithImpl;
@useResult
$Res call({
 String id, String url, int? width, int? height, int? durationMs, List<int>? waveform, String? mime
});




}
/// @nodoc
class _$MessageAttachmentCopyWithImpl<$Res>
    implements $MessageAttachmentCopyWith<$Res> {
  _$MessageAttachmentCopyWithImpl(this._self, this._then);

  final MessageAttachment _self;
  final $Res Function(MessageAttachment) _then;

/// Create a copy of MessageAttachment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? url = null,Object? width = freezed,Object? height = freezed,Object? durationMs = freezed,Object? waveform = freezed,Object? mime = freezed,}) {
  return _then(MessageAttachment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,waveform: freezed == waveform ? _self.waveform : waveform // ignore: cast_nullable_to_non_nullable
as List<int>?,mime: freezed == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageAttachment].
extension MessageAttachmentPatterns on MessageAttachment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageAttachment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageAttachment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageAttachment value)  $default,){
final _that = this;
switch (_that) {
case _MessageAttachment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageAttachment value)?  $default,){
final _that = this;
switch (_that) {
case _MessageAttachment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String url,  int? width,  int? height,  int? durationMs,  List<int>? waveform,  String? mime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageAttachment() when $default != null:
return $default(_that.id,_that.url,_that.width,_that.height,_that.durationMs,_that.waveform,_that.mime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String url,  int? width,  int? height,  int? durationMs,  List<int>? waveform,  String? mime)  $default,) {final _that = this;
switch (_that) {
case _MessageAttachment():
return $default(_that.id,_that.url,_that.width,_that.height,_that.durationMs,_that.waveform,_that.mime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String url,  int? width,  int? height,  int? durationMs,  List<int>? waveform,  String? mime)?  $default,) {final _that = this;
switch (_that) {
case _MessageAttachment() when $default != null:
return $default(_that.id,_that.url,_that.width,_that.height,_that.durationMs,_that.waveform,_that.mime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageAttachment implements MessageAttachment {
  const _MessageAttachment({required this.id, required this.url, this.width, this.height, this.durationMs,  List<int>? waveform, this.mime}): _waveform = waveform;
  factory _MessageAttachment.fromJson(Map<String, dynamic> json) => _$MessageAttachmentFromJson(json);

@override final  String id;
@override final  String url;
/// Photo size in pixels, for laying out before the image loads.
@override final  int? width;
@override final  int? height;
/// Voice note length.
@override final  int? durationMs;
/// Voice note loudness, `kVoiceWaveformBars` values 0–100, measured
/// while recording.
 final  List<int>? _waveform;
/// Voice note loudness, `kVoiceWaveformBars` values 0–100, measured
/// while recording.
@override List<int>? get waveform {
  final value = _waveform;
  if (value == null) return null;
  if (_waveform is EqualUnmodifiableListView) return _waveform;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// Content type, e.g. `audio/mp4` for a voice note.
@override final  String? mime;

/// Create a copy of MessageAttachment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageAttachmentCopyWith<_MessageAttachment> get copyWith => __$MessageAttachmentCopyWithImpl<_MessageAttachment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageAttachmentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageAttachment&&(identical(other.id, id) || other.id == id)&&(identical(other.url, url) || other.url == url)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&const DeepCollectionEquality().equals(other.waveform, _waveform)&&(identical(other.mime, mime) || other.mime == mime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,url,width,height,durationMs,const DeepCollectionEquality().hash(_waveform),mime);
}

@override
String toString() {
    return 'MessageAttachment(id: $id, url: $url, width: $width, height: $height, durationMs: $durationMs, waveform: $waveform, mime: $mime)';
}


}

/// @nodoc
abstract mixin class _$MessageAttachmentCopyWith<$Res> implements $MessageAttachmentCopyWith<$Res> {
  factory _$MessageAttachmentCopyWith(_MessageAttachment value, $Res Function(_MessageAttachment) _then) = __$MessageAttachmentCopyWithImpl;
@override @useResult
$Res call({
 String id, String url, int? width, int? height, int? durationMs, List<int>? waveform, String? mime
});




}
/// @nodoc
class __$MessageAttachmentCopyWithImpl<$Res>
    implements _$MessageAttachmentCopyWith<$Res> {
  __$MessageAttachmentCopyWithImpl(this._self, this._then);

  final _MessageAttachment _self;
  final $Res Function(_MessageAttachment) _then;

/// Create a copy of MessageAttachment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? url = null,Object? width = freezed,Object? height = freezed,Object? durationMs = freezed,Object? waveform = freezed,Object? mime = freezed,}) {
  return _then(_MessageAttachment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,waveform: freezed == waveform ? _self._waveform : waveform // ignore: cast_nullable_to_non_nullable
as List<int>?,mime: freezed == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

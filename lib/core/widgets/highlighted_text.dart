import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// [text] with the half-open [ranges] (`[start, end)`) on the
/// `matchHighlight` background: the matched part of a search result.
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    required this.text,
    required this.ranges,
    this.style,
    this.maxLines = 2,
    super.key,
  });

  final String text;
  final List<({int start, int end})> ranges;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final highlight = TextStyle(
      backgroundColor: context.bfTheme.matchHighlight,
    );
    final spans = <TextSpan>[];
    var pos = 0;
    for (final r in ranges) {
      if (r.start > pos) spans.add(TextSpan(text: text.substring(pos, r.start)));
      spans.add(
        TextSpan(text: text.substring(r.start, r.end), style: highlight),
      );
      pos = r.end;
    }
    if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));

    return Text.rich(
      TextSpan(children: spans),
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

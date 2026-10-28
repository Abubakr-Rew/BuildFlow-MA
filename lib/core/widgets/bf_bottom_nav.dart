import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/widgets/unread_badge.dart';
import 'package:flutter/material.dart';

/// A tab of [BfBottomNav].
class BfNavItem {
  const BfNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
    this.prominent = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Unread counter on the tab; hidden when 0.
  final int badgeCount;

  /// The role's main action in the middle of the bar (the foreman's new
  /// report): always an accent button rather than an icon.
  final bool prominent;
}

/// Bottom navigation: card-colored bar with a top border. The active tab
/// shows its icon in a 52×30 accent pill and a bold label.
class BfBottomNav extends StatelessWidget {
  const BfBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<BfNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavTab(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final BfNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: selected ? t.textPrimary : t.textSecondary,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        );

    final Widget icon;
    if (item.prominent) {
      icon = Container(
        width: 56,
        height: 36,
        decoration: BoxDecoration(
          color: t.accent,
          borderRadius:
              BorderRadius.circular(BuildFlowThemeExtension.iconButtonRadius),
        ),
        child: Icon(item.selectedIcon, size: 24, color: t.onAccent),
      );
    } else {
      icon = AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 52,
        height: 30,
        decoration: ShapeDecoration(
          color: selected ? t.accent : Colors.transparent,
          shape: const StadiumBorder(),
        ),
        child: Icon(
          selected ? item.selectedIcon : item.icon,
          size: 22,
          color: selected ? t.onAccent : t.textSecondary,
        ),
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        containedInkWell: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                icon,
                if (item.badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: 2,
                    // The ring keeps the badge visible on the accent pill.
                    child: UnreadBadge(
                      count: item.badgeCount,
                      ringColor: t.card,
                    ),
                  ),
              ],
            ),
            SizedBox(height: item.prominent ? 2 : 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ],
        ),
      ),
    );
  }
}

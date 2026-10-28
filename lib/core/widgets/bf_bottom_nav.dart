import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// A tab of [BfBottomNav].
class BfNavItem {
  const BfNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Unread counter on the tab; hidden when 0.
  final int badgeCount;
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
                AnimatedContainer(
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
                ),
                if (item.badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: 2,
                    child: _Badge(count: item.badgeCount),
                  ),
              ],
            ),
            const SizedBox(height: 4),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: t.accent,
        // The ring keeps the badge visible on the accent pill.
        shape: StadiumBorder(side: BorderSide(color: t.card, width: 2)),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: t.onAccent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
          fontFeatures: AppTextTheme.tabular,
        ),
      ),
    );
  }
}

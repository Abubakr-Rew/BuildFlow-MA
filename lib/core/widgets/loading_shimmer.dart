import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/widgets/bf_card.dart';
import 'package:flutter/material.dart';

/// Skeleton / shimmer loading placeholder.
class LoadingShimmer extends StatefulWidget {
  const LoadingShimmer({
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.bfTheme.muted;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _animation.value, 0),
              end: Alignment(1 + 2 * _animation.value, 0),
              colors: [muted, muted.withValues(alpha: 0.4), muted],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Shimmer list with N placeholder cards.
class LoadingShimmerList extends StatelessWidget {
  const LoadingShimmerList({this.itemCount = 5, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.screenPadding,
        vertical: AppTheme.spacing16,
      ),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppTheme.cardGap),
      itemBuilder: (context, _) => const _ShimmerCard(),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return BfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LoadingShimmer(width: 200, height: 20),
          const SizedBox(height: 12),
          const LoadingShimmer(height: 14),
          const SizedBox(height: 8),
          LoadingShimmer(
            width: MediaQuery.sizeOf(context).width * 0.6,
            height: 14,
          ),
        ],
      ),
    );
  }
}

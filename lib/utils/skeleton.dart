import 'package:flutter/material.dart';

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: borderRadius,
      ),
    );
  }
}

class SkeletonLine extends StatelessWidget {
  final double widthFactor;
  final double height;

  const SkeletonLine({
    super.key,
    this.widthFactor = 1,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: SkeletonBox(
        height: height,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class SkeletonListView extends StatelessWidget {
  final int itemCount;
  final EdgeInsets padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const SkeletonListView({
    super.key,
    this.itemCount = 8,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      shrinkWrap: shrinkWrap,
      physics: physics,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(
              width: 48,
              height: 48,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(widthFactor: 0.7),
                  SizedBox(height: 10),
                  SkeletonLine(widthFactor: 0.95),
                  SizedBox(height: 10),
                  SkeletonLine(widthFactor: 0.55),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

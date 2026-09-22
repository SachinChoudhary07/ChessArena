import 'package:cached_network_image/cached_network_image.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerAvatar extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final String fallbackAsset;

  const ShimmerAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 24,
    this.fallbackAsset = 'assets/images/pawn_image.jpg',
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl.isEmpty
            ? Image.asset(fallbackAsset, fit: BoxFit.cover)
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: size,
                height: size,
                fadeInDuration: const Duration(milliseconds: 220),
                placeholder: (_, __) => _ShimmerBox(size: size),
                errorWidget: (_, __, ___) =>
                    Image.asset(fallbackAsset, fit: BoxFit.cover),
              ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double size;

  const _ShimmerBox({required this.size});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: ColorResources.elevatedSurface,
      highlightColor: const Color(0xFF3E4552),
      period: const Duration(milliseconds: 1100),
      child: Container(
        width: size,
        height: size,
        color: ColorResources.elevatedSurface,
      ),
    );
  }
}

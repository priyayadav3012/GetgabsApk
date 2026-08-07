import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SKELETON LOADERS — animated grey placeholders shown only while the real
//  data is being fetched; swapped out for the actual content the moment it
//  arrives. Purely cosmetic — no functional behavior depends on these.
// ─────────────────────────────────────────────────────────────────────────────

class _Bone extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const _Bone({
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(6),
      ),
    );
  }
}

/// Mirrors ActiveChatListTile's shape: a leading circular avatar, a title
/// line, a subtitle line, and a small trailing time box.
class ChatListSkeleton extends StatelessWidget {
  final int rowCount;

  const ChatListSkeleton({super.key, this.rowCount = 8});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rowCount,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const _Bone(
                width: 44,
                height: 44,
                borderRadius: BorderRadius.all(Radius.circular(22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bone(width: MediaQuery.of(context).size.width * 0.4, height: 14),
                    const SizedBox(height: 8),
                    _Bone(width: MediaQuery.of(context).size.width * 0.25, height: 12),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _Bone(width: 36, height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mirrors a chat's message bubbles: alternating left/right rounded blocks
/// of varying width, for the initial load of an individual conversation.
class MessagesSkeleton extends StatelessWidget {
  const MessagesSkeleton({super.key});

  static const List<double> _widthFractions = [
    0.55, 0.35, 0.65, 0.4, 0.5, 0.3, 0.6, 0.45,
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        reverse: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: _widthFractions.length,
        itemBuilder: (context, index) {
          final isSentByMe = index.isEven;
          return Align(
            alignment:
                isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _Bone(
                width: screenWidth * _widthFractions[index],
                height: 40,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        },
      ),
    );
  }
}

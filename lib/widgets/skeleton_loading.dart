import 'package:flutter/material.dart';
import 'package:tunes4r/utils/theme_colors.dart';

/// A reusable widget that provides skeleton loading states for album grids and lists
class SkeletonLoader extends StatefulWidget {
  final int itemCount;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;
  final bool isGrid;
  final int crossAxisCount;

  const SkeletonLoader({
    super.key,
    this.itemCount = 6,
    this.height = 160,
    this.width,
    this.margin = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.borderRadius,
    this.isGrid = false,
    this.crossAxisCount = 2,
  });

  const SkeletonLoader.grid({
    super.key,
    this.itemCount = 6,
    this.height = 200,
    this.width,
    this.margin = const EdgeInsets.all(8),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.isGrid = true,
    this.crossAxisCount = 3,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGrid) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: widget.itemCount,
        itemBuilder: (context, index) => _buildSkeletonItem(),
      );
    }

    return Column(
      children: List.generate(
        widget.itemCount,
        (index) => _buildSkeletonItem(),
      ),
    );
  }

  Widget _buildSkeletonItem() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                ThemeColorsUtil.surfaceColor,
                ThemeColorsUtil.surfaceColor.withOpacity(0.8),
                ThemeColorsUtil.surfaceColor,
              ],
              stops: [
                0.0,
                _animation.value,
                1.0,
              ],
            ),
          ),
          child: SizedBox(
            height: widget.height,
            width: widget.width,
          ),
        );
      },
    );
  }
}

/// Skeleton loader specifically for album grid items
class AlbumGridSkeletonLoader extends StatelessWidget {
  final int itemCount;

  const AlbumGridSkeletonLoader({
    super.key,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const _AlbumSkeletonCard(),
    );
  }
}

/// Skeleton loader specifically for album list items
class AlbumListSkeletonLoader extends StatelessWidget {
  final int itemCount;

  const AlbumListSkeletonLoader({
    super.key,
    this.itemCount = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => const _AlbumListSkeletonItem(),
      ),
    );
  }
}

/// Individual skeleton card for album grid
class _AlbumSkeletonCard extends StatefulWidget {
  const _AlbumSkeletonCard();

  @override
  State<_AlbumSkeletonCard> createState() => _AlbumSkeletonCardState();
}

class _AlbumSkeletonCardState extends State<_AlbumSkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: ThemeColorsUtil.primaryColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Main content background
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ThemeColorsUtil.surfaceColor.withOpacity(0.8),
                        ThemeColorsUtil.surfaceColor,
                        ThemeColorsUtil.surfaceColor.withOpacity(0.9),
                      ],
                      stops: [
                        0.0,
                        _animation.value,
                        1.0,
                      ],
                    ),
                  ),
                ),

                // Album art placeholder with shimmer
                Positioned.fill(
                  child: Transform.scale(
                    scale: 1.1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            ThemeColorsUtil.primaryColor.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.music_note,
                          size: 48,
                          color: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                ),

                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.85),
                        ],
                        stops: const [0.3, 1.0],
                      ),
                    ),
                  ),
                ),

                // Album info placeholder
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Album name placeholder
                        Container(
                          height: 16,
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Second line
                        Container(
                          height: 14,
                          width: 120,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        // Track count badge
                        Container(
                          width: 80,
                          height: 20,
                          decoration: BoxDecoration(
                            color: ThemeColorsUtil.primaryColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Individual skeleton item for album list
class _AlbumListSkeletonItem extends StatefulWidget {
  const _AlbumListSkeletonItem();

  @override
  State<_AlbumListSkeletonItem> createState() => _AlbumListSkeletonItemState();
}

class _AlbumListSkeletonItemState extends State<_AlbumListSkeletonItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: ThemeColorsUtil.scaffoldBackgroundColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ThemeColorsUtil.surfaceColor,
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    ThemeColorsUtil.surfaceColor.withOpacity(0.8),
                    ThemeColorsUtil.surfaceColor,
                    ThemeColorsUtil.surfaceColor.withOpacity(0.9),
                  ],
                  stops: [0.0, _animation.value, 1.0],
                ),
              ),
              child: const Icon(Icons.music_note, size: 20, color: Color(0xFF888888)),
            ),
            title: Row(
              children: [
                // Title placeholder
                Expanded(
                  child: Container(
                    height: isMobile ? 14 : 16,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    margin: const EdgeInsets.only(bottom: 4),
                  ),
                ),
                const SizedBox(width: 8),
                // Track number placeholder
                Container(
                  width: 24,
                  height: 16,
                  decoration: BoxDecoration(
                    color: ThemeColorsUtil.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            subtitle: Container(
              height: isMobile ? 12 : 14,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            trailing: SizedBox(
              width: 160,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: List.generate(
                  4,
                  (index) => Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Combined loading screen that shows skeleton loaders with a header
class LibraryLoadingState extends StatelessWidget {
  final bool showGrid;
  final String title;
  final int itemCount;

  const LibraryLoadingState({
    super.key,
    this.showGrid = false,
    this.title = 'Loading...',
    this.itemCount = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: ThemeColorsUtil.appBarBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 16,
                width: 200,
                decoration: BoxDecoration(
                  color: ThemeColorsUtil.surfaceColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: showGrid
              ? AlbumGridSkeletonLoader(itemCount: itemCount)
              : AlbumListSkeletonLoader(itemCount: itemCount),
        ),
      ],
    );
  }
}

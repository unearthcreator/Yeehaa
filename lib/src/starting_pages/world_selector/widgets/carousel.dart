import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/models/world_config.dart';

class CarouselWidget extends StatefulWidget {
  final double availableHeight;
  final int initialIndex;
  final List<WorldConfig> worldConfigs;
  final void Function(int index)? onCenteredCardTapped;

  const CarouselWidget({
    Key? key,
    required this.availableHeight,
    this.initialIndex = 4,
    required this.worldConfigs,
    this.onCenteredCardTapped,
  }) : super(key: key);

  @override
  _CarouselWidgetState createState() => _CarouselWidgetState();
}

class _CarouselWidgetState extends State<CarouselWidget> {
  static const int carouselItemCount = 10;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    logger.i('CarouselWidget initState -> starting index=$_currentIndex');
  }

  @override
  Widget build(BuildContext context) {
    return CarouselSlider.builder(
      itemCount: carouselItemCount,
      options: CarouselOptions(
        initialPage: _currentIndex,
        height: widget.availableHeight * 0.9,
        enlargeCenterPage: true,
        enlargeStrategy: CenterPageEnlargeStrategy.scale,
        enableInfiniteScroll: false,
        viewportFraction: 0.35,
        onPageChanged: (idx, reason) {
          setState(() => _currentIndex = idx);
          final centeredWorld = _findWorldForIndex(idx);
          logger.i('Carousel changed -> idx=$idx, reason=$reason, world=${centeredWorld?.name ?? "none"}');
        },
      ),
      itemBuilder: (context, index, realIdx) {
        final world = _findWorldForIndex(index);
        return Semantics(
          button: true,
          label: world?.name ?? "Unearth",
          child: GestureDetector(
            onTap: () {
              logger.i('Card at index $index tapped.');
              if (index == _currentIndex) {
                widget.onCenteredCardTapped?.call(index);
              } else {
                logger.i('Not centered -> no action');
              }
            },
            child: Opacity(
              opacity: index == _currentIndex ? 1.0 : 0.2,
              child: AspectRatio(
                aspectRatio: 1 / 1.3,
                child: _buildCardContent(world),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardContent(WorldConfig? world) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: world != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    world.name,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FractionallySizedBox(
                      widthFactor: 0.7,
                      heightFactor: 0.7,
                      child: Image.asset(
                        _getImagePath(world),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                "Unearth",
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

   WorldConfig? _findWorldForIndex(int idx) {
    for (final w in widget.worldConfigs) {
      if (w.carouselIndex == idx) return w;
    }
    return null;
  }

  String _getImagePath(WorldConfig? world) {
    if (world == null) return 'assets/earth_snapshot/default.png';
    final mapType = world.mapType.toLowerCase();
    final theme = world.manualTheme?.toLowerCase() ?? 'day';
    final path = mapType == 'satellite'
        ? 'assets/earth_snapshot/Satellite-${theme[0].toUpperCase()}${theme.substring(1)}.png'
        : 'assets/earth_snapshot/${theme[0].toUpperCase()}${theme.substring(1)}.png';
    logger.d('Image path resolved: $path');
    return path;
  }
}



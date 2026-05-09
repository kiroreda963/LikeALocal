import 'package:flutter/material.dart';

class MapTopBar extends StatelessWidget implements PreferredSizeWidget {
  const MapTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: const Padding(
        padding: EdgeInsets.only(left: 12),
        child: CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.account_circle_outlined, color: Colors.black87),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline, color: Colors.black87),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black87),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.black87),
          onPressed: () {},
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  static const List<MapHiddenGem> _hiddenGems = [
    MapHiddenGem(
      name: 'Smart Gym',
      category: 'Hidden Gems',
      rating: 4.2,
      offset: Offset(0.60, 0.30),
      owner: HiddenGemOwner.other,
      icon: Icons.fitness_center,
    ),
    MapHiddenGem(
      name: 'Asian County',
      category: 'Food & Drink',
      rating: 4.9,
      offset: Offset(0.34, 0.48),
      owner: HiddenGemOwner.other,
      icon: Icons.restaurant,
    ),
    MapHiddenGem(
      name: 'Arcade Hub',
      category: 'Hidden Gems',
      rating: 4.8,
      offset: Offset(0.60, 0.37),
      owner: HiddenGemOwner.you,
      icon: Icons.sports_esports,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _MapPainter()),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              const _SearchBar(),
              const SizedBox(height: 14),
              const _FilterChips(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        const Positioned(
                          left: 0,
                          right: 0,
                          top: 42,
                          child: Center(child: _AreaLabel('UNION')),
                        ),
                        const Positioned(
                          left: 265,
                          top: 224,
                          child: _AreaLabel('LOWERVAILSBURG'),
                        ),
                        const Positioned(
                          left: 150,
                          top: 338,
                          child: _AreaLabel('STREET'),
                        ),
                        const Positioned(
                          left: 179,
                          top: 182,
                          child: _CurrentLocationDot(),
                        ),
                        ..._hiddenGems.map(
                          (gem) => _GemMarker(
                            gem: gem,
                            size: constraints.biggest,
                          ),
                        ),
                        Positioned(
                          right: 24,
                          bottom: 126,
                          child: _MapControlButton(
                            icon: Icons.my_location,
                            onPressed: () {},
                          ),
                        ),
                        const Positioned(
                          left: 48,
                          right: 48,
                          bottom: 30,
                          child: _FeaturedGemSheet(
                            gem: MapHiddenGem(
                              name: 'Arcade Hub',
                              category: 'Top Rated',
                              rating: 4.8,
                              offset: Offset(0.60, 0.37),
                              owner: HiddenGemOwner.you,
                              icon: Icons.sports_esports,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 220,
        height: 34,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              Icon(Icons.search, color: Colors.grey.shade400, size: 25),
              const SizedBox(width: 6),
              Text(
                'SEARCH',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Icon(Icons.filter_alt_outlined, color: Colors.grey.shade400, size: 28),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context) {
    const labels = ['HIDDEN GEMS', 'FOOD & DRINK', 'TOURIST AREAS'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: labels
          .map(
            (label) => Container(
              height: 29,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _GemMarker extends StatelessWidget {
  final MapHiddenGem gem;
  final Size size;

  const _GemMarker({required this.gem, required this.size});

  @override
  Widget build(BuildContext context) {
    final left = (size.width * gem.offset.dx) - 72;
    final top = (size.height * gem.offset.dy) - 24;
    final isMine = gem.owner == HiddenGemOwner.you;

    return Positioned(
      left: left.clamp(6, size.width - 145).toDouble(),
      top: top.clamp(0, size.height - 72).toDouble(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isMine ? const Color(0xFFFF2323) : const Color(0xFF143C23),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(gem.icon, color: Colors.white, size: isMine ? 23 : 25),
          ),
        if (!isMine)
          _MapCallout(
            name: gem.name,
            rating: gem.rating,
          ),
        ],
      ),
    );
  }
}

class _MapCallout extends StatelessWidget {
  final String name;
  final double rating;

  const _MapCallout({
    required this.name,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(-3, 0),
      child: Container(
        height: 27,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Color(0xFF219357),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE5FF00),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Icon(Icons.star, color: Colors.black, size: 7),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedGemSheet extends StatelessWidget {
  final MapHiddenGem gem;

  const _FeaturedGemSheet({required this.gem});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.11),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 73,
              height: 84,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=300',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFEDEDED),
                      child: const Icon(Icons.sports_esports, color: Colors.black54),
                    ),
                  ),
                  const Positioned(
                    left: 2,
                    top: 4,
                    child: _TopRatedBadge(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        gem.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    const Icon(Icons.star, color: Color(0xFFFFCA28), size: 18),
                    Text(
                      gem.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                const Text(
                  '0.3 KM away - New Cairo',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      height: 29,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.chat_bubble_outline, color: Colors.black, size: 18),
                          SizedBox(width: 5),
                          Text(
                            'Chat with owner',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 31,
                      height: 31,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC4C9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bookmark_border,
                        color: Color(0xFFFF6375),
                        size: 23,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopRatedBadge extends StatelessWidget {
  const _TopRatedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE7FF00),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'TOP RATED',
        style: TextStyle(
          color: Colors.black,
          fontSize: 5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MapControlButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: const Color(0xFF1B6E38), size: 29),
        ),
      ),
    );
  }
}

class _CurrentLocationDot extends StatelessWidget {
  const _CurrentLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF89CEFF), width: 2),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF3E61FF),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _AreaLabel extends StatelessWidget {
  final String label;

  const _AreaLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.black.withOpacity(0.42),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFA8FFC6), BlendMode.src);

    final blockPaint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..style = PaintingStyle.fill;
    final roadFill = Paint()
      ..color = const Color(0xFFE9F2E6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final roadEdge = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    void road(List<Offset> points) {
      final path = Path()..moveTo(points.first.dx * size.width, points.first.dy * size.height);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path, roadEdge);
      canvas.drawPath(path, roadFill);
    }

    road(const [Offset(-0.02, 0.78), Offset(0.24, 0.88), Offset(0.16, 1.04)]);
    road(const [Offset(0.01, 0.22), Offset(0.18, 0.31), Offset(0.16, 0.49), Offset(-0.02, 0.63)]);
    road(const [Offset(0.19, 0.26), Offset(0.56, -0.05), Offset(0.84, 0.21), Offset(1.06, 0.35)]);
    road(const [Offset(0.55, -0.02), Offset(0.76, 0.26), Offset(0.63, 0.74), Offset(0.55, 1.03)]);
    road(const [Offset(0.37, 0.31), Offset(0.57, 0.53), Offset(0.47, 0.96)]);
    road(const [Offset(0.07, 0.50), Offset(0.26, 0.64), Offset(0.47, 0.68)]);
    road(const [Offset(0.20, 0.86), Offset(0.45, 0.95), Offset(0.68, 0.88), Offset(1.02, 0.90)]);
    road(const [Offset(0.80, 0.50), Offset(0.95, 0.43), Offset(1.05, 0.47)]);
    road(const [Offset(0.82, 0.19), Offset(0.90, 0.12)]);
    road(const [Offset(0.49, 0.23), Offset(0.68, 0.44)]);
    road(const [Offset(0.58, 0.50), Offset(0.78, 0.64), Offset(1.04, 0.65)]);
    road(const [Offset(0.18, 0.03), Offset(0.17, 0.17), Offset(0.01, 0.27)]);

    final blocks = [
      Rect.fromLTWH(size.width * 0.86, size.height * 0.48, 42, 56),
      Rect.fromLTWH(size.width * 0.80, size.height * 0.57, 78, 37),
      Rect.fromLTWH(size.width * 0.13, size.height * 0.40, 12, 14),
      Rect.fromLTWH(size.width * 0.22, size.height * 0.43, 12, 14),
      Rect.fromLTWH(size.width * 0.93, size.height * 0.33, 9, 9),
      Rect.fromLTWH(size.width * 0.69, size.height * 0.77, 13, 12),
      Rect.fromLTWH(size.width * 0.29, size.height * 0.36, 13, 13),
      Rect.fromLTWH(size.width * 0.57, size.height * 0.43, 28, 9),
      Rect.fromLTWH(size.width * 0.72, size.height * 0.84, 14, 12),
    ];

    for (final rect in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        blockPaint,
      );
    }

    _drawRotatedLabel(canvas, size, 'Street name', const Offset(0.27, 0.17), -0.85);
    _drawRotatedLabel(canvas, size, 'Street name', const Offset(0.28, 0.62), 0.15);
    _drawRotatedLabel(canvas, size, 'Street name', const Offset(0.62, 0.41), -1.42);
    _drawRotatedLabel(canvas, size, 'Street name', const Offset(0.75, 0.57), -1.18);
    _drawRotatedLabel(canvas, size, 'Street name', const Offset(0.53, 0.76), -1.12);
  }

  void _drawRotatedLabel(Canvas canvas, Size size, String text, Offset offset, double angle) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black.withOpacity(0.34),
          fontSize: 6,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(offset.dx * size.width, offset.dy * size.height);
    canvas.rotate(angle);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum HiddenGemOwner { you, other }

class MapHiddenGem {
  final String name;
  final String category;
  final double rating;
  final Offset offset;
  final HiddenGemOwner owner;
  final IconData icon;

  const MapHiddenGem({
    required this.name,
    required this.category,
    required this.rating,
    required this.offset,
    required this.owner,
    required this.icon,
  });
}

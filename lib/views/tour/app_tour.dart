import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tour_providers.dart';

/// Widgets the tour points at. Each is wrapped in a [KeyedSubtree] with one of
/// these keys where it is built, so the tour can find it on screen.
abstract final class TourTargets {
  static final date = GlobalKey(debugLabel: 'tour-date');
  static final totals = GlobalKey(debugLabel: 'tour-totals');
  static final addFood = GlobalKey(debugLabel: 'tour-add-food');
  static final settings = GlobalKey(debugLabel: 'tour-settings');
  static final catalogTab = GlobalKey(debugLabel: 'tour-catalog-tab');
  static final summaryTab = GlobalKey(debugLabel: 'tour-summary-tab');
}

class TourStep {
  const TourStep({required this.title, required this.body, this.target});

  final String title;
  final String body;

  /// What to highlight. Null shows the card in the middle of the screen.
  final GlobalKey? target;
}

final tourSteps = [
  TourStep(
    target: TourTargets.date,
    title: 'Pick a day',
    body:
        'Use the arrows to move between days, and tap the date to jump back '
        'to today. Anything you log goes to the day shown here.',
  ),
  TourStep(
    target: TourTargets.totals,
    title: 'Your totals',
    body: 'What you have eaten so far, measured against your daily goals.',
  ),
  TourStep(
    target: TourTargets.addFood,
    title: 'Log food',
    body:
        'Tap + to log something. Pick a recent food, a saved food or meal '
        'from your catalog, or enter a one-off food.',
  ),
  const TourStep(
    title: 'Your log',
    body:
        'Logged food is listed under your totals. Tap an entry to change its '
        'servings, or swipe it left to delete it. On an empty day you can '
        'copy the day before in one tap.',
  ),
  TourStep(
    target: TourTargets.catalogTab,
    title: 'Catalog',
    body:
        'Save the foods you eat often, or scan a barcode to fill in the '
        'nutrition facts. Combine foods into meals to log them in one tap, '
        'or plan a meal for certain days.',
  ),
  TourStep(
    target: TourTargets.summaryTab,
    title: 'Summary',
    body:
        'Your daily averages and a chart, for a day, a week, or up to a year.',
  ),
  TourStep(
    target: TourTargets.settings,
    title: 'Settings',
    body:
        'Change your goals, what you track and your units, and back up your '
        'data. You can replay this tour from there too.',
  ),
];

/// Dims the screen except for the current step's target and explains it.
/// Sits above the tabs and shows nothing while [tourProvider] is null.
class AppTourOverlay extends ConsumerStatefulWidget {
  const AppTourOverlay({super.key});

  @override
  ConsumerState<AppTourOverlay> createState() => _AppTourOverlayState();
}

class _AppTourOverlayState extends ConsumerState<AppTourOverlay> {
  /// Frames to keep measuring after a change. Long enough to follow a target
  /// through a page transition, such as Settings popping back to Today.
  static const _trackFrames = 60;

  Rect? _hole;
  int _framesLeft = 0;
  bool _measureScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Runs on the first build and whenever the screen size changes.
    _track();
  }

  void _track() {
    if (ref.read(tourProvider) == null) return;
    _framesLeft = _trackFrames;
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      final hole = _measure();
      if (hole != _hole) setState(() => _hole = hole);
      if (--_framesLeft > 0) {
        _scheduleMeasure();
        SchedulerBinding.instance.scheduleFrame();
      }
    });
  }

  /// The target's rect in this overlay's coordinates, or null when there is
  /// no target or it is off screen.
  Rect? _measure() {
    final step = ref.read(tourProvider);
    if (step == null) return null;
    final target = tourSteps[step].target?.currentContext?.findRenderObject();
    final overlay = context.findRenderObject();
    if (target is! RenderBox || !target.hasSize || overlay is! RenderBox) {
      return null;
    }
    final topLeft = overlay.globalToLocal(target.localToGlobal(Offset.zero));
    final rect = (topLeft & target.size).inflate(6);
    return rect.overlaps(Offset.zero & overlay.size) ? rect : null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tourProvider, (_, _) => _track());
    final step = ref.watch(tourProvider);
    if (step == null) return const SizedBox.shrink();

    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: _TourCard(step: step),
    );
    final size = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);
    final hole = _hole;

    // The card goes on whichever side of the target has more room, or in the
    // middle when there is no target or too little room beside it.
    final below = hole != null && hole.center.dy < size.height / 2;
    final (double, double)? topAndBottom = switch (hole) {
      null => null,
      final h when below => (h.bottom + 12, insets.bottom + 16),
      final h => (insets.top + 16, size.height - h.top + 12),
    };
    // Room for the buttons and a few lines of text, at the current text size.
    final minRoom = MediaQuery.textScalerOf(context).scale(160);
    final Widget placed;
    if (topAndBottom case (
      final top,
      final bottom,
    ) when size.height - top - bottom >= minRoom) {
      placed = Positioned(
        left: 16,
        right: 16,
        top: top,
        bottom: bottom,
        child: Align(
          alignment: below ? Alignment.topCenter : Alignment.bottomCenter,
          child: card,
        ),
      );
    } else {
      placed = Positioned.fill(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: card),
          ),
        ),
      );
    }

    // Blocks taps and screen-reader focus on the app underneath.
    return BlockSemantics(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(
                painter: _ScrimPainter(
                  hole: hole,
                  color: const Color(0xB3000000),
                ),
              ),
            ),
          ),
          placed,
        ],
      ),
    );
  }
}

class _TourCard extends ConsumerWidget {
  const _TourCard({required this.step});

  final int step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tour = ref.read(tourProvider.notifier);
    final last = step == tourSteps.length - 1;
    final info = tourSteps[step];
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Container(
      key: const Key('tour-card'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Only the text scrolls, so the buttons stay on screen at large
          // text sizes.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${step + 1} of ${tourSteps.length}',
                    style: TextStyle(fontSize: 13, color: secondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(info.body),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              if (!last)
                CupertinoButton(
                  key: const Key('tour-skip'),
                  padding: EdgeInsets.zero,
                  onPressed: tour.finish,
                  child: const Text('Skip tour'),
                )
              else
                const SizedBox.shrink(),
              CupertinoButton(
                key: const Key('tour-next'),
                onPressed: () => tour.next(tourSteps.length),
                child: Text(
                  last ? 'Done' : 'Next',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A full-screen scrim with a rounded hole over the highlighted widget.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter({required this.hole, required this.color});

  final Rect? hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Offset.zero & size);
    if (hole case final Rect hole) {
      path
        ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(12)))
        ..fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.color != color;
}

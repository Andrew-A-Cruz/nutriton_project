import 'package:flutter/cupertino.dart';

typedef _WelcomePage = ({IconData icon, String title, String body});

const _pages = <_WelcomePage>[
  (
    icon: CupertinoIcons.heart_circle_fill,
    title: 'Welcome to Nutriton',
    body:
        'A quick, simple food log. Log what you eat and see how it adds up '
        'against your goals.',
  ),
  (
    icon: CupertinoIcons.plus_circle_fill,
    title: 'Log in a few taps',
    body:
        'Pick a recent food, a saved food or meal, or type in a one-off. '
        'Scan a barcode to fill in nutrition facts for you.',
  ),
  (
    icon: CupertinoIcons.book_fill,
    title: 'Build your catalog',
    body:
        'Save the foods you eat often and combine them into meals. Plan a '
        'meal for certain days and it shows up on Today, ready to confirm.',
  ),
  (
    icon: CupertinoIcons.chart_bar_fill,
    title: 'See your progress',
    body:
        'Today shows your totals for the day. Summary shows your averages '
        'over a week, a month or a year.',
  ),
  (
    icon: CupertinoIcons.lock_shield_fill,
    title: 'Your data stays yours',
    body:
        'No account and no ads. Everything is stored on this device, and you '
        'can export a backup from Settings at any time.',
  ),
];

/// Intro pages shown before the setup form on first launch. Calls [onDone]
/// from the last page or from Skip.
class WelcomePages extends StatefulWidget {
  const WelcomePages({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<WelcomePages> createState() => _WelcomePagesState();
}

class _WelcomePagesState extends State<WelcomePages> {
  final _controller = PageController();
  int _page = 0;

  bool get _last => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) {
      widget.onDone();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              // Kept in the layout on the last page, so the pages don't jump.
              child: Visibility.maintain(
                visible: !_last,
                child: CupertinoButton(
                  key: const Key('welcome-skip'),
                  onPressed: widget.onDone,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                key: const Key('welcome-pages'),
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: [for (final page in _pages) _PageBody(page: page)],
              ),
            ),
            _Dots(count: _pages.length, current: _page),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  key: const Key('welcome-next'),
                  onPressed: _next,
                  child: Text(_last ? 'Set up' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.page});

  final _WelcomePage page;

  @override
  Widget build(BuildContext context) {
    return Center(
      // Scrolls at large text sizes instead of overflowing.
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          children: [
            Icon(
              page.icon,
              size: 72,
              color: CupertinoTheme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              page.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              page.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page indicator: one dot per page, the current one filled.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final on = CupertinoTheme.of(context).primaryColor;
    final off = CupertinoColors.systemGrey4.resolveFrom(context);
    return Semantics(
      label: 'Page ${current + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == current ? on : off,
              ),
            ),
        ],
      ),
    );
  }
}

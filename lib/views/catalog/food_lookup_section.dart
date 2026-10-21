import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/metrics.dart';
import '../../providers/food_lookup_providers.dart';
import 'barcode_scanner_page.dart';

/// "Look up" block for the new-food form: a barcode field and a name search
/// that list Open Food Facts products. Tapping a result calls [onPick] so the
/// form can prefill; nothing is saved here.
class FoodLookupSection extends ConsumerStatefulWidget {
  const FoodLookupSection({super.key, required this.onPick});

  final ValueChanged<FoodLookupResult> onPick;

  @override
  ConsumerState<FoodLookupSection> createState() => _FoodLookupSectionState();
}

enum _Status { idle, loading, notFound, error, results }

class _FoodLookupSectionState extends ConsumerState<FoodLookupSection> {
  final _barcode = TextEditingController();
  final _query = TextEditingController();

  _Status _status = _Status.idle;
  String? _error;
  List<FoodLookupResult> _results = const [];

  /// Bumped per request so a slow, older reply cannot overwrite a newer one.
  int _request = 0;

  @override
  void dispose() {
    _barcode.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _run(Future<List<FoodLookupResult>> Function() fetch) async {
    final id = ++_request;
    setState(() {
      _status = _Status.loading;
      _error = null;
    });
    try {
      final results = await fetch();
      if (!mounted || id != _request) return;
      setState(() {
        _results = results;
        _status = results.isEmpty ? _Status.notFound : _Status.results;
      });
    } on FoodLookupException catch (e) {
      if (!mounted || id != _request) return;
      setState(() {
        _status = _Status.error;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted || id != _request) return;
      setState(() {
        _status = _Status.error;
        _error = 'Something went wrong. Try again.';
      });
    }
  }

  void _lookupBarcode() => _run(() async {
    final repo = ref.read(foodLookupRepositoryProvider);
    final product = await repo.findByBarcode(_barcode.text);
    return product == null ? const [] : [product];
  });

  /// Opens the camera, then fills the barcode field and looks it up. A null
  /// result (cancelled) leaves everything as it was.
  Future<void> _scan() async {
    final code = await ref.read(barcodeScannerProvider)(context);
    if (!mounted || code == null || code.isEmpty) return;
    _barcode.text = code;
    _lookupBarcode();
  }

  void _search() => _run(
    () => ref.read(foodLookupRepositoryProvider).searchByName(_query.text),
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoFormSection.insetGrouped(
      header: const Text('LOOK UP (OPEN FOOD FACTS)'),
      footer: const Text(
        'Fills the form below. Check the values and edit before saving.',
      ),
      children: [
        _field(
          fieldKey: const Key('lookup-barcode'),
          controller: _barcode,
          placeholder: 'Barcode digits',
          numeric: true,
          buttonKey: const Key('lookup-barcode-go'),
          buttonLabel: 'Find',
          onGo: _lookupBarcode,
          onScan: ref.watch(barcodeScanSupportedProvider) ? _scan : null,
        ),
        _field(
          fieldKey: const Key('lookup-query'),
          controller: _query,
          placeholder: 'Search by name',
          numeric: false,
          buttonKey: const Key('lookup-query-go'),
          buttonLabel: 'Search',
          onGo: _search,
        ),
        ..._statusRows(),
      ],
    );
  }

  Widget _field({
    required Key fieldKey,
    required TextEditingController controller,
    required String placeholder,
    required bool numeric,
    required Key buttonKey,
    required String buttonLabel,
    required VoidCallback onGo,
    VoidCallback? onScan,
  }) {
    final busy = _status == _Status.loading;
    return CupertinoFormRow(
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              key: fieldKey,
              controller: controller,
              placeholder: placeholder,
              keyboardType: numeric ? TextInputType.number : TextInputType.text,
              textInputAction: TextInputAction.search,
              onSubmitted: busy ? null : (_) => onGo(),
            ),
          ),
          if (onScan != null)
            CupertinoButton(
              key: const Key('lookup-barcode-scan'),
              padding: const EdgeInsets.only(left: 12),
              onPressed: busy ? null : onScan,
              child: const Icon(CupertinoIcons.barcode_viewfinder),
            ),
          CupertinoButton(
            key: buttonKey,
            padding: const EdgeInsets.only(left: 12),
            onPressed: busy ? null : onGo,
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  List<Widget> _statusRows() {
    switch (_status) {
      case _Status.idle:
        return const [];
      case _Status.loading:
        return const [
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CupertinoActivityIndicator(key: Key('lookup-loading')),
            ),
          ),
        ];
      case _Status.notFound:
        return const [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No match found. Try another search or enter it by hand.',
              key: Key('lookup-not-found'),
            ),
          ),
        ];
      case _Status.error:
        return [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error ?? 'Lookup failed.',
              key: const Key('lookup-error'),
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
          ),
        ];
      case _Status.results:
        return [
          for (var i = 0; i < _results.length; i++)
            _ResultRow(
              key: Key('lookup-result-$i'),
              result: _results[i],
              onTap: () => widget.onPick(_results[i]),
            ),
        ];
    }
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({super.key, required this.result, required this.onTap});

  final FoodLookupResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final serving = result.hasServingSize
        ? '${plainNumber(result.servingWeightG)} g serving'
        : 'per 100 g';
    final detail = result.hasNutrition
        ? '${plainNumber(result.perServing.calories)} kcal, $serving'
        : 'No nutrition data';
    final brand = result.brand;
    return CupertinoListTile(
      onTap: onTap,
      title: Text(result.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        brand == null ? detail : '$brand - $detail',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const CupertinoListTileChevron(),
    );
  }
}

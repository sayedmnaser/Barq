import 'package:flutter/material.dart';

import '../models/place_result.dart';
import '../services/bahrain_map_service.dart';
import '../settings.dart';

class BahrainPlaceSearchSheet extends StatefulWidget {
  const BahrainPlaceSearchSheet({
    super.key,
    required this.language,
    required this.title,
    this.initialQuery = '',
  });

  final AppLanguage language;
  final String title;
  final String initialQuery;

  static Future<PlaceResult?> show(
    BuildContext context, {
    required AppLanguage language,
    required String title,
    String initialQuery = '',
  }) {
    return showModalBottomSheet<PlaceResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: BahrainPlaceSearchSheet(
          language: language,
          title: title,
          initialQuery: initialQuery,
        ),
      ),
    );
  }

  @override
  State<BahrainPlaceSearchSheet> createState() =>
      _BahrainPlaceSearchSheetState();
}

class _BahrainPlaceSearchSheetState extends State<BahrainPlaceSearchSheet> {
  late final TextEditingController _queryController;
  bool _loading = false;
  String? _errorText;
  List<PlaceResult> _results = const <PlaceResult>[];

  bool get _isArabic => widget.language == AppLanguage.ar;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().isNotEmpty) {
      _performSearch(widget.initialQuery.trim());
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorText = null;
        _results = const <PlaceResult>[];
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final results = await BahrainMapService.searchPlaces(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = results;
        _loading = false;
        _errorText = results.isEmpty ? _emptyText : null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _results = const <PlaceResult>[];
        _errorText = _errorMessage;
      });
    }
  }

  String get _searchHint => _isArabic
      ? 'ابحث عن موقع داخل البحرين'
      : 'Search for a location in Bahrain';

  String get _helperText => _isArabic
      ? 'اكتب اسم المنطقة أو الشارع أو المعلم ثم اضغط بحث.'
      : 'Type an area, road, or landmark, then press search.';

  String get _emptyText => _isArabic
      ? 'لم يتم العثور على نتائج.'
      : 'No Bahrain locations found.';

  String get _errorMessage => _isArabic
      ? 'تعذر تحميل نتائج البحث الآن.'
      : 'Could not load search results right now.';

  String get _searchActionLabel => _isArabic ? 'بحث' : 'Search';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            _helperText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _queryController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: _searchHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : SizedBox(
                      width: 96,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_queryController.text.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                _queryController.clear();
                                setState(() {
                                  _results = const <PlaceResult>[];
                                  _errorText = null;
                                });
                              },
                              icon: const Icon(Icons.clear),
                            ),
                          IconButton(
                            onPressed: () =>
                                _performSearch(_queryController.text.trim()),
                            icon: Transform.flip(
                              flipX: Directionality.of(context) ==
                                  TextDirection.rtl,
                              child: const Icon(Icons.arrow_forward),
                            ),
                            tooltip: _searchActionLabel,
                          ),
                        ],
                      ),
                    ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (value) => _performSearch(value.trim()),
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 12),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _errorText!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _queryController.text.trim().isEmpty
                          ? _searchHint
                          : _emptyText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final place = _results[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        leading: const CircleAvatar(
                          child: Icon(Icons.location_on_outlined),
                        ),
                        title: Text(place.title),
                        subtitle: Text(place.subtitle.isEmpty
                            ? '${place.latitude.toStringAsFixed(5)}, ${place.longitude.toStringAsFixed(5)}'
                            : place.subtitle),
                        onTap: () => Navigator.of(context).pop(place),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

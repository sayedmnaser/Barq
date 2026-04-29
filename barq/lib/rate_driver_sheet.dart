import 'package:flutter/material.dart';

import 'models/tow_request_model.dart';
import 'services/pocketbase_service.dart';

class RateDriverSheet extends StatefulWidget {
  const RateDriverSheet({super.key, required this.request, required this.driverUserId});

  final TowRequest request;
  final String driverUserId;

  static Future<bool?> show(
    BuildContext context, {
    required TowRequest request,
    required String driverUserId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RateDriverSheet(request: request, driverUserId: driverUserId),
      ),
    );
  }

  @override
  State<RateDriverSheet> createState() => _RateDriverSheetState();
}

class _RateDriverSheetState extends State<RateDriverSheet> {
  int _stars = 5;
  final _commentController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await PocketBaseService.instance.createRating(
        towRequestId: widget.request.id,
        driverUserId: widget.driverUserId,
        stars: _stars,
        comment: _commentController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save rating: $e')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Rate ${widget.request.driverName ?? 'driver'}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _stars;
              return IconButton(
                iconSize: 36,
                onPressed: () => setState(() => _stars = i + 1),
                icon: Icon(
                  filled ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit rating'),
          ),
        ],
      ),
    );
  }
}

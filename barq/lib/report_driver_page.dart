import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models/tow_request_model.dart';
import 'services/moderation_ai_service.dart';
import 'services/pocketbase_service.dart';

class ReportDriverPage extends StatefulWidget {
  const ReportDriverPage({
    super.key,
    this.driverUserId,
    this.driverName,
    this.towRequest,
  });

  final String? driverUserId;
  final String? driverName;
  final TowRequest? towRequest;

  @override
  State<ReportDriverPage> createState() => _ReportDriverPageState();
}

class _ReportDriverPageState extends State<ReportDriverPage> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  String _category = 'rude';
  final List<File> _photos = <File>[];
  bool _submitting = false;

  static const _categories = <(String value, String label)>[
    ('rude', 'Rude / unprofessional'),
    ('unsafe', 'Unsafe driving'),
    ('no_show', 'No show'),
    ('damage', 'Damaged vehicle'),
    ('fraud', 'Fraud / overcharge'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 5) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() => _photos.add(File(picked.path)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final pb = PocketBaseService.instance;
    try {
      final report = await pb.createDriverReport(
        driverUserId: widget.driverUserId,
        towRequestId: widget.towRequest?.id,
        category: _category,
        description: _descController.text,
        photoPaths: _photos.map((f) => f.path).toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. AI reviewing...')),
      );

      // Fire-and-forget AI verdict
      _runAiVerdict(report.id);

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit: $e')),
      );
      setState(() => _submitting = false);
    }
  }

  Future<void> _runAiVerdict(String reportId) async {
    try {
      final pb = PocketBaseService.instance;
      final record = await pb.getRecord('driver_reports', reportId);
      final urls = <String>[];
      for (final f in record.getListValue<String>('photos')) {
        urls.add(pb.fileUrl(record, f));
      }
      final verdict = await ModerationAiService.instance.reviewDriverReport(
        category: record.getStringValue('category'),
        description: record.getStringValue('description'),
        photoUrls: urls,
      );
      await pb.applyAiReportVerdict(
        reportId: reportId,
        aiVerdict: verdict.reasoning,
        aiAction: verdict.action,
        aiConfidence: verdict.confidence,
      );
    } catch (_) {
      // best-effort; admin can retry
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.driverName == null
            ? 'Report driver'
            : 'Report ${widget.driverName}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Issue type'),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? 'other'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 10) {
                  return 'At least 10 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Photos (${_photos.length}/5)'),
                ),
                TextButton.icon(
                  onPressed: _photos.length >= 5 ? null : _addPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _photos[i],
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: -8,
                        top: -8,
                        child: IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => setState(() => _photos.removeAt(i)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
  }
}

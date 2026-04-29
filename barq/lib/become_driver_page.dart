import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pocketbase/pocketbase.dart';

import 'services/moderation_ai_service.dart';
import 'services/pocketbase_service.dart';

class BecomeDriverPage extends StatefulWidget {
  const BecomeDriverPage({super.key});

  @override
  State<BecomeDriverPage> createState() => _BecomeDriverPageState();
}

enum _DocSlot { licenseFront, licenseBack, nationalId, carPhoto }

class _BecomeDriverPageState extends State<BecomeDriverPage> {
  final _pb = PocketBaseService.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();
  final Map<_DocSlot, File> _docs = <_DocSlot, File>{};

  bool _loading = true;
  bool _submitting = false;
  RecordModel? _existing;

  @override
  void initState() {
    super.initState();
    _nameController.text = _pb.currentUserName;
    _loadExisting();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final app = await _pb.getMyDriverApplication();
      if (!mounted) return;
      setState(() {
        _existing = app;
        if (app != null) {
          _nameController.text = app.getStringValue('full_name');
          _plateController.text = app.getStringValue('plate_number');
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDoc(_DocSlot slot) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;
    setState(() {
      _docs[slot] = File(picked.path);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_docs.length < 4) {
      _snack('Capture all 4 documents first.');
      return;
    }
    setState(() => _submitting = true);

    try {
      final record = await _pb.submitDriverApplication(
        fullName: _nameController.text,
        plateNumber: _plateController.text,
        licenseFrontPath: _docs[_DocSlot.licenseFront]!.path,
        licenseBackPath: _docs[_DocSlot.licenseBack]!.path,
        nationalIdPath: _docs[_DocSlot.nationalId]!.path,
        carPhotoPath: _docs[_DocSlot.carPhoto]!.path,
      );

      if (mounted) _snack('Submitted. AI reviewing...');
      await _runAiReview(record);
    } catch (e) {
      if (mounted) _snack('Submit failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _runAiReview(RecordModel record) async {
    try {
      final fullName = record.getStringValue('full_name');
      final plate = record.getStringValue('plate_number');

      final verdict = await ModerationAiService.instance.reviewDriverApplication(
        fullName: fullName,
        plateNumber: plate,
        licenseFrontUrl: _pb.fileUrl(record, record.getStringValue('license_front')),
        licenseBackUrl: _pb.fileUrl(record, record.getStringValue('license_back')),
        nationalIdUrl: _pb.fileUrl(record, record.getStringValue('national_id')),
        carPhotoUrl: _pb.fileUrl(record, record.getStringValue('car_photo')),
      );

      final updated = await _pb.applyAiApplicationVerdict(
        applicationId: record.id,
        aiVerdict: verdict.reasoning,
        aiDecision: verdict.decision,
        aiConfidence: verdict.confidence,
      );

      if (!mounted) return;
      setState(() => _existing = updated);
      _snack('AI: ${verdict.decision} (${(verdict.confidence * 100).round()}%)');
    } catch (e) {
      if (mounted) _snack('AI review error: $e');
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final status = _existing?.getStringValue('status') ?? '';
    final aiVerdict = _existing?.getStringValue('ai_verdict') ?? '';
    final isLocked = status == 'approved' || status == 'rejected';

    return Scaffold(
      appBar: AppBar(title: const Text('Become a driver')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (status.isNotEmpty) _statusCard(status, aiVerdict),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                enabled: !isLocked,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plateController,
                enabled: !isLocked,
                decoration: const InputDecoration(labelText: 'Car plate number'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _docTile(_DocSlot.licenseFront, 'License (front)', isLocked),
              _docTile(_DocSlot.licenseBack, 'License (back)', isLocked),
              _docTile(_DocSlot.nationalId, 'National ID', isLocked),
              _docTile(_DocSlot.carPhoto, 'Car photo', isLocked),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (_submitting || isLocked) ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_existing == null ? 'Submit application' : 'Resubmit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard(String status, String aiVerdict) {
    Color bg;
    String label;
    switch (status) {
      case 'approved':
        bg = Colors.green.shade100;
        label = 'Approved by AI';
        break;
      case 'rejected':
        bg = Colors.red.shade100;
        label = 'Rejected';
        break;
      case 'ai_reviewed':
        bg = Colors.amber.shade100;
        label = 'Pending human review';
        break;
      default:
        bg = Colors.blue.shade100;
        label = 'Submitted';
    }
    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (aiVerdict.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(aiVerdict),
            ],
          ],
        ),
      ),
    );
  }

  Widget _docTile(_DocSlot slot, String title, bool locked) {
    final file = _docs[slot];
    return Card(
      child: ListTile(
        leading: file == null
            ? const Icon(Icons.camera_alt_outlined)
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(file, width: 48, height: 48, fit: BoxFit.cover),
              ),
        title: Text(title),
        subtitle: Text(file == null ? 'Not captured' : 'Captured'),
        trailing: TextButton(
          onPressed: locked ? null : () => _pickDoc(slot),
          child: Text(file == null ? 'Capture' : 'Retake'),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import 'services/pocketbase_service.dart';
import 'settings.dart';

const Color kLightningYellow = Color(0xFFF4C21E);
const Color kLightningNavy = Color(0xFF0B1220);

class SignInPage extends StatefulWidget {
  const SignInPage({
    super.key,
    required this.language,
    required this.onToggleLanguage,
    required this.onAuthenticated,
    required this.onGoToSignUp,
  });

  final AppLanguage language;
  final VoidCallback onToggleLanguage;
  final VoidCallback onAuthenticated;
  final VoidCallback onGoToSignUp;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

enum _OtpDelivery { email, phone }

class _SignInPageState extends State<SignInPage> {
  final PocketBaseService _pocketBaseService = PocketBaseService.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _identityController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  _OtpDelivery _delivery = _OtpDelivery.email;
  bool _isSubmitting = false;
  bool _otpSent = false;
  String? _otpId;
  bool? _serverReachable;

  bool get _isArabic => widget.language == AppLanguage.ar;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  @override
  void dispose() {
    _identityController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final reachable = await _pocketBaseService.ping();
    if (!mounted) return;
    setState(() => _serverReachable = reachable);
  }

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _cardColor(BuildContext context) =>
      _isDark(context) ? kLightningCard : Colors.white;

  Color _borderColor(BuildContext context) =>
      _isDark(context) ? kLightningBorder : kLightningLightBorder;

  Color _mutedColor(BuildContext context) =>
      _isDark(context) ? kLightningMuted : kLightningLightMuted;

  String get _identityHint {
    if (_delivery == _OtpDelivery.email) {
      return _isArabic ? 'البريد الإلكتروني' : 'Email address';
    }
    return _isArabic ? 'رقم الهاتف' : 'Phone number';
  }

  Future<void> _sendOtp(AppStrings strings) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final identity =
          _pocketBaseService.resolveIdentity(_identityController.text);
      final otpId = await _pocketBaseService.requestOtp(identity);
      if (!mounted) return;
      setState(() {
        _otpId = otpId;
        _otpSent = true;
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('otpSentTo'))),
      );
    } on ClientException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final msg = e.response['message'] as String? ??
          strings.text('otpSendFailed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } on SocketException {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('pocketbaseSetupMissing'))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('otpSendFailed'))),
      );
    }
  }

  Future<void> _verifyOtp(AppStrings strings) async {
    final code = _otpController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('otpInvalid'))),
      );
      return;
    }
    if (_otpId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('sendOtpFirst'))),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _pocketBaseService.authWithOtp(otpId: _otpId!, code: code);
      if (!mounted) return;
      widget.onAuthenticated();
    } on ClientException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final msg = e.response['message'] as String? ??
          strings.text('otpVerificationFailed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('otpVerificationFailed'))),
      );
    }
  }

  String get _connectionTitle =>
      _isArabic ? 'اتصال PocketBase' : 'PocketBase connection';

  String get _connectionMessage {
    if (_serverReachable == true) {
      return _isArabic
          ? 'الخادم متصل وجاهز لتسجيل الدخول.'
          : 'Server is reachable and ready for sign in.';
    }
    return _isArabic
        ? 'تأكد من تشغيل PocketBase وتمرير POCKETBASE_URL الصحيح.'
        : 'Make sure PocketBase is running and POCKETBASE_URL is correct.';
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.language);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardColor(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _borderColor(context)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header ──
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              _isDark(context)
                                  ? 'lib/src/logo/file_00000000decc7246a92d743d9b9850f3.png'
                                  : 'lib/src/logo/file_0000000031dc72468f1c079a0115f272.png',
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              strings.text('appName'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onToggleLanguage,
                            child: Text(
                              widget.language == AppLanguage.en
                                  ? strings.text('arabic')
                                  : strings.text('english'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        strings.text('signIn'),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.text('signInSubtitle'),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: _mutedColor(context)),
                      ),
                      const SizedBox(height: 16),

                      // ── Connection banner ──
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _serverReachable == true
                              ? const Color(0xFFECFDF3)
                              : (_isDark(context)
                                  ? const Color(0xFF2A1A15)
                                  : const Color(0xFFFFF7ED)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _serverReachable == true
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFF97316),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _serverReachable == true
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_off_outlined,
                              color: _serverReachable == true
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFF97316),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _connectionTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _connectionMessage,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _pocketBaseService.serverUrl,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: _mutedColor(context)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── OTP delivery toggle ──
                      Row(
                        children: [
                          Text(
                            strings.text('otpDelivery'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 12),
                          ChoiceChip(
                            label: Text(strings.text('otpViaEmail')),
                            selected: _delivery == _OtpDelivery.email,
                            onSelected: (_) {
                              setState(() {
                                _delivery = _OtpDelivery.email;
                                _otpSent = false;
                                _otpId = null;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(strings.text('otpViaPhone')),
                            selected: _delivery == _OtpDelivery.phone,
                            onSelected: (_) {
                              setState(() {
                                _delivery = _OtpDelivery.phone;
                                _otpSent = false;
                                _otpId = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Identity field ──
                      TextFormField(
                        controller: _identityController,
                        keyboardType: _delivery == _OtpDelivery.email
                            ? TextInputType.emailAddress
                            : TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: _identityHint,
                          hintText: _delivery == _OtpDelivery.phone
                              ? strings.text('phoneFormatHint')
                              : null,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) {
                            return strings.text('requiredField');
                          }
                          if (_delivery == _OtpDelivery.email &&
                              !v.contains('@')) {
                            return strings.text('validEmail');
                          }
                          if (_delivery == _OtpDelivery.phone &&
                              _pocketBaseService.normalizePhone(v) == null) {
                            return strings.text('validPhone');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // ── Send / Resend OTP button ──
                      if (!_otpSent)
                        FilledButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => _sendOtp(strings),
                          style: FilledButton.styleFrom(
                            backgroundColor: kLightningYellow,
                            foregroundColor: kLightningNavy,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            _isSubmitting
                                ? strings.text('sendingOtp')
                                : strings.text('sendOtp'),
                          ),
                        ),

                      // ── OTP code entry + verify ──
                      if (_otpSent) ...[
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: strings.text('otpCode'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => _verifyOtp(strings),
                          style: FilledButton.styleFrom(
                            backgroundColor: kLightningYellow,
                            foregroundColor: kLightningNavy,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            _isSubmitting
                                ? strings.text('verifyingOtp')
                                : strings.text('signIn'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => _sendOtp(strings),
                          child: Text(strings.text('resendOtp')),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: widget.onGoToSignUp,
                        child: Text(strings.text('noAccountSignUp')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

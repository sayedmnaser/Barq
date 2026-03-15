import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import 'services/pocketbase_service.dart';
import 'settings.dart';

const Color kLightningYellow = Color(0xFFF4C21E);
const Color kLightningNavy = Color(0xFF0B1220);

class SignUpPage extends StatefulWidget {
  const SignUpPage({
    super.key,
    required this.language,
    required this.onToggleLanguage,
    required this.onAuthenticated,
    required this.onGoToSignIn,
  });

  final AppLanguage language;
  final VoidCallback onToggleLanguage;
  final VoidCallback onAuthenticated;
  final VoidCallback onGoToSignIn;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final PocketBaseService _pocketBaseService = PocketBaseService.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSubmitting = false;
  bool? _serverReachable;

  bool get _isArabic => widget.language == AppLanguage.ar;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final reachable = await _pocketBaseService.ping();
    if (!mounted) {
      return;
    }
    setState(() {
      _serverReachable = reachable;
    });
  }

  bool _isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color _cardColor(BuildContext context) {
    return _isDark(context) ? kLightningCard : Colors.white;
  }

  Color _borderColor(BuildContext context) {
    return _isDark(context) ? kLightningBorder : kLightningLightBorder;
  }

  Color _mutedColor(BuildContext context) {
    return _isDark(context) ? kLightningMuted : kLightningLightMuted;
  }

  Future<void> _submit(AppStrings strings) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isNotEmpty && _pocketBaseService.normalizePhone(rawPhone) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('validPhone'))),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _pocketBaseService.signUp(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
        phone: rawPhone,
      );

      if (!mounted) {
        return;
      }
      widget.onAuthenticated();
    } on ClientException catch (e) {
      if (!mounted) {
        return;
      }

      String message = strings.text('signUpFailed');
      final data = e.response['data'];
      if (data is Map) {
        final errors = data.entries
            .where((entry) => entry.value is Map && entry.value['message'] != null)
            .map((entry) => '${entry.key}: ${entry.value['message']}')
            .toList(growable: false);
        if (errors.isNotEmpty) {
          message = errors.join('\n');
        }
      } else if (e.response['message'] is String) {
        message = e.response['message'] as String;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on SocketException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('pocketbaseSetupMissing'))),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('signUpFailed'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String get _connectionTitle =>
      _isArabic ? 'اتصال PocketBase' : 'PocketBase connection';

  String get _connectionMessage {
    if (_serverReachable == true) {
      return _isArabic
          ? 'الخادم متصل ويمكن إنشاء الحساب.'
          : 'Server is reachable and ready for account creation.';
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
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              'lib/src/logo/white_mod.png',
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
                        strings.text('signUp'),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.text('signUpSubtitle'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _mutedColor(context),
                            ),
                      ),
                      const SizedBox(height: 16),
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
                                        ?.copyWith(fontWeight: FontWeight.w700),
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
                                        ?.copyWith(color: _mutedColor(context)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _fullNameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: strings.text('fullName'),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return strings.text('requiredField');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: strings.text('emailAddress'),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty || !email.contains('@')) {
                            return strings.text('validEmail');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: strings.text('phoneNumber'),
                          hintText: strings.text('phoneFormatHint'),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final phone = value?.trim() ?? '';
                          if (phone.isNotEmpty &&
                              _pocketBaseService.normalizePhone(phone) == null) {
                            return strings.text('validPhone');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: strings.text('password'),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if ((value ?? '').length < 8) {
                            return strings.text('passwordTooShort');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: strings.text('confirmPassword'),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return strings.text('passwordMismatch');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _isSubmitting ? null : () => _submit(strings),
                        style: FilledButton.styleFrom(
                          backgroundColor: kLightningYellow,
                          foregroundColor: kLightningNavy,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _isSubmitting
                              ? strings.text('creatingAccount')
                              : strings.text('createAccount'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: widget.onGoToSignIn,
                        child: Text(strings.text('haveAccountSignIn')),
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

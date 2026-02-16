import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String? _otpEmail;
  bool _otpSent = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;

  bool get _isSupabaseConfigured {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
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

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp(AppStrings strings) async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('validEmail'))),
      );
      return;
    }

    if (!_isSupabaseConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('supabaseSetupMissing'))),
      );
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _otpEmail = email;
        _otpSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('otpSentTo'))),
      );
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(exception.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('otpSendFailed'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
      }
    }
  }

  Future<bool> _verifyOtp(AppStrings strings) async {
    final otpEmail = _otpEmail;
    final code = _otpController.text.trim();

    if (otpEmail == null || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('otpInvalid'))),
      );
      return false;
    }

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.email,
        email: otpEmail,
        token: code,
      );

      if (!mounted) {
        return false;
      }

      final isVerified =
          response.session != null ||
          response.user != null ||
          Supabase.instance.client.auth.currentUser != null;

      if (!isVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.text('otpInvalid'))),
        );
      }

      return isVerified;
    } on AuthException catch (exception) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(exception.message)),
      );
      return false;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('signInFailed'))),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
      }
    }
  }

  Future<void> _submit(AppStrings strings) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_otpSent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('sendOtpFirst'))),
      );
      return;
    }

    final verified = await _verifyOtp(strings);
    if (!verified) {
      return;
    }

    widget.onAuthenticated();
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
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardColor(context),
                  borderRadius: BorderRadius.circular(16),
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
                              style: Theme.of(context).textTheme.titleLarge
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
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.text('signInSubtitle'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _mutedColor(context),
                        ),
                      ),
                      const SizedBox(height: 20),
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
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: strings.text('otpCode'),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return strings.text('requiredField');
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _isSendingOtp
                                ? null
                                : () {
                                    _sendOtp(strings);
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: kLightningYellow,
                              foregroundColor: kLightningNavy,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            child: Text(
                              _isSendingOtp
                                  ? strings.text('sendingOtp')
                                  : (_otpSent
                                        ? strings.text('resendOtp')
                                        : strings.text('sendOtp')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _isVerifyingOtp
                            ? null
                            : () {
                                _submit(strings);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: kLightningYellow,
                          foregroundColor: kLightningNavy,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _isVerifyingOtp
                              ? strings.text('verifyingOtp')
                              : strings.text('signIn'),
                        ),
                      ),
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

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

class _SignInPageState extends State<SignInPage> {
  final PocketBaseService _pocketBaseService = PocketBaseService.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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
    _emailController.dispose();
    _passwordController.dispose();
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

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _pocketBaseService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      widget.onAuthenticated();
    } on ClientException catch (e) {
      if (!mounted) {
        return;
      }
      final message =
          e.response['message'] as String? ?? strings.text('signInFailed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('signInFailed'))),
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
                        strings.text('signIn'),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.text('signInSubtitle'),
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
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: strings.text('password'),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return strings.text('requiredField');
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
                              ? strings.text('signingIn')
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

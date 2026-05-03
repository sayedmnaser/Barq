import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'become_driver_page.dart';
import 'driver_page.dart';
import 'get_estimate_page.dart';
import 'models/tow_request_model.dart';
import 'rate_driver_sheet.dart';
import 'report_driver_page.dart';
import 'models/user_model.dart';
import 'request_tow_page.dart';
import 'services/app_preferences_service.dart';
import 'services/driver_location_service.dart';
import 'services/location_service.dart';
import 'services/pocketbase_service.dart';
import 'settings.dart';
import 'sign_in_page.dart';
import 'sign_up_page.dart';
import 'support_chat_page.dart';
import 'track_service_page.dart';

const Color kLightningYellow = Color(0xFFF4C21E);
const Color kLightningNavy = Color(0xFF0B1220);
const Color kLightningCard = Color(0xFF141B2D);
const Color kLightningBorder = Color(0xFF27314A);
const Color kLightningMuted = Color(0xFF9AA3B2);
const Color kLightningLightBackground = Color(0xFFF7F7FB);
const Color kLightningLightBorder = Color(0xFFE5E7EB);
const Color kLightningLightMuted = Color(0xFF6B7280);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PocketBaseService.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final PocketBaseService _pocketBaseService = PocketBaseService.instance;

  ThemeMode _themeMode = ThemeMode.dark;
  AppLanguage _language = AppLanguage.en;
  bool _isAuthenticated = false;
  bool _showSignUp = false;
  bool _showDriverPanel = true;
  StreamSubscription<dynamic>? _authSubscription;

  UserProfile _currentUserProfile = const UserProfile(
    firstName: 'User',
    lastName: '',
    email: 'unknown@example.com',
    role: 'Customer',
    totalRides: 0,
    totalSpent: '0.000',
    memberSince: 'Now',
  );

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _isAuthenticated = _pocketBaseService.isAuthenticated;
    _currentUserProfile =
        _buildUserProfile(_pocketBaseService.currentUserRecord);

    _authSubscription =
        _pocketBaseService.client.authStore.onChange.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAuthenticated = _pocketBaseService.isAuthenticated;
        final refreshedProfile =
            _buildUserProfile(_pocketBaseService.currentUserRecord);
        _currentUserProfile = refreshedProfile;
        if (!_canAccessDriverPanel()) {
          _showDriverPanel = false;
        } else if (_showDriverPanel == false) {
          // Keep user's chosen view for driver accounts.
        } else {
          _showDriverPanel = true;
        }
        if (_isAuthenticated) {
          _showSignUp = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final isDark = prefs.getBool('isDarkMode') ?? true;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      final langCode = prefs.getString('language') ?? 'en';
      _language = langCode == 'ar' ? AppLanguage.ar : AppLanguage.en;
    });
  }

  Future<void> _saveTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }

  Future<void> _saveLanguage(AppLanguage lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang == AppLanguage.ar ? 'ar' : 'en');
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
    _saveTheme(_themeMode == ThemeMode.dark);
  }

  void _toggleLanguage() {
    setState(() {
      _language = _language == AppLanguage.en ? AppLanguage.ar : AppLanguage.en;
    });
    _saveLanguage(_language);
  }

  void _showSignInPage() {
    setState(() {
      _showSignUp = false;
    });
  }

  void _showSignUpPage() {
    setState(() {
      _showSignUp = true;
    });
  }

  UserProfile _buildUserProfile(RecordModel? record) {
    if (record == null) {
      return const UserProfile(
        firstName: 'User',
        lastName: '',
        email: 'unknown@example.com',
        role: 'Customer',
        totalRides: 0,
        totalSpent: '0.000',
        memberSince: 'Now',
      );
    }

    final user = User.fromRecord(record);
    final memberSince = '${user.created.year}-'
        '${user.created.month.toString().padLeft(2, '0')}-'
        '${user.created.day.toString().padLeft(2, '0')}';

    final phoneStr = user.phoneNumber > 0 ? user.phoneNumber.toString() : null;

    return UserProfile(
      id: user.id,
      firstName: user.firstName,
      lastName: user.lastName,
      email: user.email.isNotEmpty ? user.email : 'unknown@example.com',
      role: _roleLabel(user.role),
      totalRides: 0,
      totalSpent: '0.000',
      memberSince: memberSince,
      phoneNumber: phoneStr,
      verified: user.verified,
      avatarUrl: user.avatarUrl(_pocketBaseService.serverUrl),
    );
  }

  Future<void> _logout() async {
    await DriverLocationService.instance.stop();
    await _pocketBaseService.signOut();
    if (!mounted) {
      return;
    }
    setState(() {
      _isAuthenticated = false;
      _showDriverPanel = true;
      _currentUserProfile = const UserProfile(
        firstName: 'User',
        lastName: '',
        email: 'unknown@example.com',
        role: 'Customer',
        totalRides: 0,
        totalSpent: '0.000',
        memberSince: 'Now',
      );
    });
  }

  bool _isDriverRole(String role) {
    return User.normalizeRole(role) == 'driver';
  }

  bool _canAccessDriverPanel() {
    return _isDriverRole(_currentUserProfile.role) &&
        _pocketBaseService.isCurrentUserDriverToggleEnabled;
  }

  String _roleLabel(String role) {
    final normalized = User.normalizeRole(role);
    if (normalized == 'driver') {
      return 'Driver';
    }
    return 'Customer';
  }

  void _openDriverPanel() {
    if (!_canAccessDriverPanel()) {
      return;
    }
    setState(() {
      _showDriverPanel = true;
    });
  }

  void _openCustomerHome() {
    setState(() {
      _showDriverPanel = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barq',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kLightningYellow,
          brightness: Brightness.light,
        ).copyWith(
          primary: kLightningYellow,
          onPrimary: kLightningNavy,
          outline: kLightningLightBorder,
          onSurfaceVariant: kLightningLightMuted,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: kLightningLightBackground,
        cardColor: Colors.white,
        dividerColor: kLightningLightBorder,
        hintColor: kLightningLightMuted,
        appBarTheme: const AppBarTheme(
          backgroundColor: kLightningLightBackground,
          foregroundColor: kLightningNavy,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kLightningYellow,
          brightness: Brightness.dark,
        ).copyWith(
          primary: kLightningYellow,
          onPrimary: kLightningNavy,
          outline: kLightningBorder,
          onSurfaceVariant: kLightningMuted,
          surface: kLightningCard,
        ),
        scaffoldBackgroundColor: kLightningNavy,
        cardColor: kLightningCard,
        dividerColor: kLightningBorder,
        hintColor: kLightningMuted,
        appBarTheme: const AppBarTheme(
          backgroundColor: kLightningNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: _language == AppLanguage.ar
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _isAuthenticated
          ? (_canAccessDriverPanel() && _showDriverPanel
              ? DriverPage(
                  language: _language,
                  onSwitchToCustomerView: _openCustomerHome,
                )
              : HomePage(
                  user: _currentUserProfile,
                  language: _language,
                  showOpenDriverPanel: _canAccessDriverPanel(),
                  onToggleLanguage: _toggleLanguage,
                  onToggleTheme: _toggleTheme,
                  onOpenDriverPanel: _openDriverPanel,
                  onLogout: _logout,
                ))
          : (_showSignUp
              ? SignUpPage(
                  language: _language,
                  onToggleLanguage: _toggleLanguage,
                  onAuthenticated: () {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _isAuthenticated = true;
                      _showSignUp = false;
                    });
                  },
                  onGoToSignIn: _showSignInPage,
                )
              : SignInPage(
                  language: _language,
                  onToggleLanguage: _toggleLanguage,
                  onAuthenticated: () {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _isAuthenticated = true;
                      _showSignUp = false;
                    });
                  },
                  onGoToSignUp: _showSignUpPage,
                )),
    );
  }
}

class ActiveRequest {
  const ActiveRequest({
    required this.id,
    required this.driverName,
    required this.truckType,
    required this.rating,
    required this.etaMinutes,
    required this.distanceKm,
    required this.statusLabel,
    this.pickupLocation = '',
    this.destination = '',
    this.licensePlate = '',
    this.driverTotalRides = 0,
    this.baseFare = 0,
    this.distanceFare = 0,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.driverLat,
    this.driverLng,
    this.driverUserId,
    this.rated = false,
    required this.source,
  });

  final String id;
  final String driverName;
  final String truckType;
  final double rating;
  final int etaMinutes;
  final double distanceKm;
  final String statusLabel;
  final String pickupLocation;
  final String destination;
  final String licensePlate;
  final int driverTotalRides;
  final double baseFare;
  final double distanceFare;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final double? driverLat;
  final double? driverLng;
  final String? driverUserId;
  final bool rated;
  final TowRequest source;

  factory ActiveRequest.fromTowRequest(TowRequest request) {
    return ActiveRequest(
      id: request.id,
      driverName: request.driverName ?? 'Assigning...',
      truckType: request.vehicleType,
      rating: request.driverRating ?? 0,
      etaMinutes: request.etaMinutes ?? 0,
      distanceKm: request.distanceKm ?? 0,
      statusLabel: request.status,
      pickupLocation: request.pickupLocation,
      destination: request.destination,
      licensePlate: request.licensePlate ?? '',
      driverTotalRides: request.driverTotalRides ?? 0,
      baseFare: request.baseFare ?? 0,
      distanceFare: request.distanceFare ?? 0,
      pickupLat: request.pickupLat,
      pickupLng: request.pickupLng,
      destinationLat: request.destinationLat,
      destinationLng: request.destinationLng,
      driverLat: request.driverLat,
      driverLng: request.driverLng,
      driverUserId: request.driverUserId,
      rated: request.rated,
      source: request,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.user,
    required this.language,
    required this.showOpenDriverPanel,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    required this.onOpenDriverPanel,
    required this.onLogout,
  });

  final UserProfile user;
  final AppLanguage language;
  final bool showOpenDriverPanel;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenDriverPanel;
  final VoidCallback onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PocketBaseService _pocketBaseService = PocketBaseService.instance;

  List<ActiveRequest> _activeRequests = const <ActiveRequest>[];
  List<ActiveRequest> _serviceHistory = const <ActiveRequest>[];
  bool _isLoading = true;
  bool _isRealtimeSubscribed = false;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _subscribeToRealtimeUpdates();
    _warmupPickupLocation();
  }

  @override
  void dispose() {
    if (_isRealtimeSubscribed) {
      _pocketBaseService.unsubscribeCurrentUserRequests();
    }
    super.dispose();
  }

  Future<void> _subscribeToRealtimeUpdates() async {
    try {
      await _pocketBaseService.subscribeCurrentUserRequests(() {
        if (mounted) {
          _loadRequests();
        }
      });
      _isRealtimeSubscribed = true;
    } catch (_) {
      // Keep manual refresh path if realtime is unavailable.
    }
  }

  Future<void> _warmupPickupLocation() async {
    try {
      final shareLocationEnabled =
          await AppPreferencesService.getShareLocationEnabled();
      if (!shareLocationEnabled) {
        return;
      }

      final cached = await AppPreferencesService.getLastPickupPlace();
      if (cached != null) {
        return;
      }

      final wasPrompted = await AppPreferencesService.getAutoLocationPrompted();
      if (wasPrompted) {
        final silentPlace = await LocationService.tryGetCurrentPlaceSilently();
        if (silentPlace != null) {
          await AppPreferencesService.saveLastPickupPlace(silentPlace);
        }
        return;
      }

      await AppPreferencesService.setAutoLocationPrompted(true);
      final place = await LocationService.getCurrentPlace();
      await AppPreferencesService.saveLastPickupPlace(place);
    } catch (_) {
      // Non-blocking warmup. Manual location buttons remain available.
    }
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final active = await _pocketBaseService.getActiveRequests();
      final history = await _pocketBaseService.getServiceHistory();
      if (!mounted) {
        return;
      }
      setState(() {
        _activeRequests = active.map(ActiveRequest.fromTowRequest).toList();
        _serviceHistory = history.map(ActiveRequest.fromTowRequest).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
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

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFF6B7280);
      case 'assigned':
        return const Color(0xFF2563EB);
      case 'en_route':
        return const Color(0xFFF59E0B);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'cancel_pending':
        return const Color(0xFFB45309);
      default:
        return kLightningYellow;
    }
  }

  Widget _statusPill(BuildContext context, String status, AppStrings strings) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status, strings),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  String _statusLabel(String status, AppStrings strings) {
    switch (status) {
      case 'pending':
        return strings.text('pending');
      case 'assigned':
        return strings.text('assigned');
      case 'en_route':
        return strings.text('enRoute');
      case 'completed':
        return strings.text('completed');
      case 'cancelled':
        return strings.text('cancelled');
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.language);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRequests,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _buildTopBar(context, strings),
              const SizedBox(height: 20),
              Text(
                strings.welcome(widget.user.firstName),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.text('help'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _mutedColor(context),
                    ),
              ),
              const SizedBox(height: 18),
              _buildActionCard(
                context,
                icon: Icons.local_shipping_outlined,
                iconColor: kLightningYellow,
                title: strings.text('requestTow'),
                subtitle: strings.text('requestTowSub'),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RequestTowPage(language: widget.language),
                    ),
                  );
                  _loadRequests();
                },
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                context,
                icon: Icons.map_outlined,
                iconColor: const Color(0xFF16A34A),
                title: strings.text('trackService'),
                subtitle: strings.text('trackServiceSub'),
                onTap: () {
                  if (_activeRequests.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.text('noHistoryTitle'))),
                    );
                    return;
                  }

                  final request = _activeRequests.first;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TrackServicePage(
                        requestId: request.id,
                        pickupLocation: request.pickupLocation,
                        destinationLocation: request.destination,
                        vehicleDescription: request.truckType,
                        licensePlate: request.licensePlate,
                        driverName: request.driverName,
                        driverRating: request.rating,
                        driverTotalRides: request.driverTotalRides,
                        distanceKm: request.distanceKm,
                        remainingDistanceKm: request.distanceKm,
                        etaMinutes: request.etaMinutes,
                        baseFare: request.baseFare,
                        distanceFare: request.distanceFare,
                        pickupLat: request.pickupLat,
                        pickupLng: request.pickupLng,
                        destinationLat: request.destinationLat,
                        destinationLng: request.destinationLng,
                        driverLat: request.driverLat,
                        driverLng: request.driverLng,
                        language: widget.language,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                context,
                icon: Icons.support_agent_outlined,
                iconColor: const Color(0xFFF97316),
                title: widget.language == AppLanguage.ar
                    ? 'دردشة الدعم'
                    : 'Support Chat',
                subtitle: widget.language == AppLanguage.ar
                    ? 'تحدث مع مساعد ذكي لحل المشاكل بسرعة'
                    : 'Chat with an AI assistant for quick help',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SupportChatPage(language: widget.language),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                context,
                icon: Icons.attach_money,
                iconColor: const Color(0xFF2563EB),
                title: strings.text('getEstimate'),
                subtitle: strings.text('getEstimateSub'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          GetEstimatePage(language: widget.language),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              if (widget.showOpenDriverPanel) ...[
                _buildActionCard(
                  context,
                  icon: Icons.local_shipping_outlined,
                  iconColor: const Color(0xFF7C3AED),
                  title: widget.language == AppLanguage.ar
                      ? 'فتح لوحة السائق'
                      : 'Open Driver Panel',
                  subtitle: widget.language == AppLanguage.ar
                      ? 'التبديل إلى شاشة السائق في أي وقت'
                      : 'Switch to the driver screen at any time',
                  onTap: widget.onOpenDriverPanel,
                ),
                const SizedBox(height: 12),
              ],
              if (!widget.showOpenDriverPanel) ...[
                _buildActionCard(
                  context,
                  icon: Icons.badge_outlined,
                  iconColor: const Color(0xFF059669),
                  title: widget.language == AppLanguage.ar
                      ? 'كن سائقًا'
                      : 'Become a driver',
                  subtitle: widget.language == AppLanguage.ar
                      ? 'قدّم طلبك للمراجعة بواسطة الذكاء الاصطناعي'
                      : 'Submit documents for AI review',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BecomeDriverPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
              ] else
                const SizedBox(height: 6),
              _buildTabs(context, strings),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_tabIndex == 0 && _activeRequests.isEmpty)
                _buildEmptyState(context, strings)
              else if (_tabIndex == 1 && _serviceHistory.isEmpty)
                _buildEmptyState(context, strings)
              else
                ...(_tabIndex == 0 ? _activeRequests : _serviceHistory)
                    .map((request) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildRequestCard(context, request, strings),
                        )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, AppStrings strings) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            Theme.of(context).brightness == Brightness.dark
                ? 'lib/src/logo/file_00000000decc7246a92d743d9b9850f3.png'
                : 'lib/src/logo/file_0000000031dc72468f1c079a0115f272.png',
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.text('appName'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                strings.text('dashboard'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _mutedColor(context),
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsPage(
                  user: widget.user,
                  language: widget.language,
                  isDark: _isDark(context),
                  onToggleTheme: widget.onToggleTheme,
                  onToggleLanguage: widget.onToggleLanguage,
                ),
              ),
            );
          },
          icon: Icon(
            Icons.settings_outlined,
            color: _isDark(context) ? Colors.white : kLightningNavy,
          ),
          tooltip: strings.text('settings'),
        ),
        IconButton(
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout, color: kLightningYellow),
          tooltip: strings.text('logout'),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _mutedColor(context),
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs(BuildContext context, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _isDark(context)
            ? const Color(0xFF1A2336)
            : const Color(0xFFEFF1F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _buildTabButton(
            context,
            label: strings.text('activeRequests'),
            index: 0,
          ),
          _buildTabButton(
            context,
            label: strings.text('serviceHistory'),
            index: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context, {
    required String label,
    required int index,
  }) {
    final isSelected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _cardColor(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? (_isDark(context) ? Colors.white : kLightningNavy)
                        : _mutedColor(context),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    ActiveRequest request,
    AppStrings strings,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _isDark(context)
                    ? const Color(0xFF202A3F)
                    : const Color(0xFFE5E7EB),
                child: Text(
                  request.driverName.isEmpty ? '?' : request.driverName[0],
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.driverName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.truckType,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _mutedColor(context),
                          ),
                    ),
                  ],
                ),
              ),
              _statusPill(context, request.statusLabel, strings),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            request.pickupLocation,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            request.destination,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mutedColor(context),
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (request.statusLabel == 'completed' ||
                  request.statusLabel == 'cancelled')
                _infoPill(
                  context,
                  icon: Icons.event_outlined,
                  label: widget.language == AppLanguage.ar ? 'التاريخ' : 'Date',
                  value: _formatShortDate(request.source.updated),
                )
              else
                _infoPill(
                  context,
                  icon: Icons.schedule,
                  label: strings.text('eta'),
                  value: request.etaMinutes > 0
                      ? '${request.etaMinutes} min'
                      : '--',
                ),
              const SizedBox(width: 12),
              _infoPill(
                context,
                icon: Icons.place_outlined,
                label: strings.text('distance'),
                value: '${request.distanceKm.toStringAsFixed(1)} km',
              ),
              if (request.distanceKm > 0) ...[
                const SizedBox(width: 12),
                _infoPill(
                  context,
                  icon: Icons.payments_outlined,
                  label: 'Fare',
                  value: '${_displayFareFor(request).toStringAsFixed(3)} BHD',
                ),
              ],
            ],
          ),
          if (request.statusLabel == 'completed') ...[
            const SizedBox(height: 12),
            _historyActions(context, request),
          ],
        ],
      ),
    );
  }

  String _formatShortDate(DateTime value) {
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '${value.year}-$m-$d';
  }

  double _tierFare(double km) {
    if (km <= 0) return 10.0;
    if (km <= 15) return 10.0;
    if (km <= 20) return 15.0;
    return 20.0;
  }

  double _displayFareFor(ActiveRequest request) {
    final km = request.distanceKm;
    final base = _tierFare(km);
    final stored = request.source.distanceFare ?? 0;
    final night = stored > 0 && stored <= 5.001 ? stored : 0.0;
    return base + night;
  }

  Widget _historyActions(BuildContext context, ActiveRequest request) {
    final hasDriverInfo =
        request.driverUserId != null || request.driverName.trim().isNotEmpty;
    final canRate = hasDriverInfo && !request.rated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (request.rated) _buildGivenRatingBadge(context, request),
        if (request.rated) const SizedBox(height: 8),
        Row(
          children: [
            if (canRate)
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Rate'),
                  onPressed: () async {
                    var driverUserId = request.driverUserId;
                    if (driverUserId == null || driverUserId.isEmpty) {
                      driverUserId = await _pocketBaseService
                          .resolveDriverUserIdByName(request.driverName);
                    }
                    if (driverUserId == null || driverUserId.isEmpty) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not identify the driver to rate. Try again later.',
                          ),
                        ),
                      );
                      return;
                    }
                    if (!context.mounted) return;
                    final saved = await RateDriverSheet.show(
                      context,
                      request: request.source,
                      driverUserId: driverUserId,
                    );
                    if (saved == true) {
                      await _loadRequests();
                    }
                  },
                ),
              ),
            if (canRate) const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.flag_outlined,
                    color: Colors.red, size: 18),
                label: Text(
                  canRate ? 'Report' : 'Report bad driver',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReportDriverPage(
                        driverUserId: request.driverUserId,
                        driverName: request.driverName,
                        towRequest: request.source,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGivenRatingBadge(BuildContext context, ActiveRequest request) {
    return FutureBuilder<RecordModel?>(
      future: _pocketBaseService.getRatingForRequest(request.id),
      builder: (context, snapshot) {
        final record = snapshot.data;
        final stars = record?.getIntValue('stars') ?? 0;
        final comment = record?.getStringValue('comment').trim() ?? '';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isDark(context)
                ? const Color(0xFF101827)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Row(
            children: [
              ...List.generate(5, (i) {
                return Icon(
                  i < stars ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 16,
                );
              }),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  comment.isEmpty ? 'You rated this trip' : comment,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _mutedColor(context),
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _isDark(context)
              ? const Color(0xFF101827)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor(context)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _mutedColor(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _mutedColor(context),
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 40, color: kLightningYellow),
          const SizedBox(height: 12),
          Text(
            strings.text('noHistoryTitle'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.text('noHistoryBody'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mutedColor(context),
                ),
          ),
        ],
      ),
    );
  }
}

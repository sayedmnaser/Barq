import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'driver_page.dart';
import 'get_estimate_page.dart';
import 'models/tow_request_model.dart';
import 'models/user_model.dart';
import 'request_tow_page.dart';
import 'services/app_preferences_service.dart';
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
  bool? _databaseReachable;
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
        _currentUserProfile =
            _buildUserProfile(_pocketBaseService.currentUserRecord);
        if (_isAuthenticated) {
          _showSignUp = false;
        }
      });
    });

    _refreshDatabaseStatus();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshDatabaseStatus() async {
    final reachable = await _pocketBaseService.ping();
    if (!mounted) {
      return;
    }
    setState(() {
      _databaseReachable = reachable;
    });
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
    await _pocketBaseService.signOut();
    if (!mounted) {
      return;
    }
    setState(() {
      _isAuthenticated = false;
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

  String _roleLabel(String role) {
    final normalized = User.normalizeRole(role);
    if (normalized == 'driver') {
      return 'Driver';
    }
    return 'Customer';
  }

  Future<void> _switchToDriverRole() async {
    await _pocketBaseService.updateCurrentUserRole('driver');
    try {
      await _pocketBaseService.ensureCurrentDriverProfile();
    } catch (_) {
      // Role switch remains successful even if driver profile setup is missing.
    }
    final refreshed = await _pocketBaseService.refreshCurrentUserRecord();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUserProfile =
          _buildUserProfile(refreshed ?? _pocketBaseService.currentUserRecord);
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
        ),
        scaffoldBackgroundColor: kLightningLightBackground,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kLightningYellow,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: kLightningNavy,
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
          ? (_isDriverRole(_currentUserProfile.role)
              ? DriverPage(language: _language)
              : HomePage(
                  user: _currentUserProfile,
                  language: _language,
                  databaseReachable: _databaseReachable,
                  onToggleLanguage: _toggleLanguage,
                  onToggleTheme: _toggleTheme,
                  onRefreshDatabaseStatus: _refreshDatabaseStatus,
                  onBecomeDriver: _switchToDriverRole,
                  onLogout: _logout,
                ))
          : (_showSignUp
              ? SignUpPage(
                  language: _language,
                  onToggleLanguage: _toggleLanguage,
                  onAuthenticated: () {
                    _refreshDatabaseStatus();
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
                    _refreshDatabaseStatus();
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
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.user,
    required this.language,
    required this.databaseReachable,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    required this.onRefreshDatabaseStatus,
    required this.onBecomeDriver,
    required this.onLogout,
  });

  final UserProfile user;
  final AppLanguage language;
  final bool? databaseReachable;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final Future<void> Function() onRefreshDatabaseStatus;
  final Future<void> Function() onBecomeDriver;
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
  bool _isSwitchingRole = false;
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

  String _connectionTitle(AppLanguage language) {
    return language == AppLanguage.ar
        ? 'اتصال قاعدة البيانات'
        : 'Database connection';
  }

  String _connectionMessage(AppLanguage language) {
    final reachable = widget.databaseReachable;
    if (reachable == true) {
      return language == AppLanguage.ar
          ? 'PocketBase متصل ويعمل.'
          : 'PocketBase is connected and reachable.';
    }
    return language == AppLanguage.ar
        ? 'تأكد من تشغيل PocketBase وتمرير POCKETBASE_URL الصحيح.'
        : 'Make sure PocketBase is running and POCKETBASE_URL is correct.';
  }

  Future<void> _handleBecomeDriver() async {
    setState(() {
      _isSwitchingRole = true;
    });

    try {
      await widget.onBecomeDriver();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account switched to Driver. Opening driver panel...'),
        ),
      );
    } on ClientException catch (e) {
      if (!mounted) {
        return;
      }
      final message = e.response['message'] as String? ??
          'Could not switch account to driver. Check users update rule and role field.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not switch account to driver.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingRole = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.language);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await widget.onRefreshDatabaseStatus();
            await _loadRequests();
          },
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
              if (widget.databaseReachable != true) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isDark(context)
                        ? const Color(0xFF2A1A15)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF97316)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.cloud_off_outlined,
                            color: Color(0xFFF97316)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _connectionTitle(widget.language),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _connectionMessage(widget.language),
                              style: Theme.of(context).textTheme.bodySmall,
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
                const SizedBox(height: 16),
              ],
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
              _buildActionCard(
                context,
                icon: Icons.switch_account_outlined,
                iconColor: const Color(0xFF7C3AED),
                title:
                    _isSwitchingRole ? 'Switching account...' : 'Become Driver',
                subtitle: 'Change account type and open the driver-only screen',
                onTap: () {
                  if (_isSwitchingRole) {
                    return;
                  }
                  _handleBecomeDriver();
                },
              ),
              const SizedBox(height: 18),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kLightningYellow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(request.statusLabel, strings),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: kLightningNavy,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
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
              _infoPill(
                context,
                icon: Icons.schedule,
                label: strings.text('eta'),
                value: '${request.etaMinutes} min',
              ),
              const SizedBox(width: 12),
              _infoPill(
                context,
                icon: Icons.place_outlined,
                label: strings.text('distance'),
                value: '${request.distanceKm.toStringAsFixed(1)} km',
              ),
            ],
          ),
        ],
      ),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _mutedColor(context),
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
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

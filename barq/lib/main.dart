import 'package:flutter/material.dart';
import 'settings.dart';

const Color kLightningYellow = Color(0xFFF4C21E);
const Color kLightningNavy = Color(0xFF0B1220);
const Color kLightningCard = Color(0xFF141B2D);
const Color kLightningBorder = Color(0xFF27314A);
const Color kLightningMuted = Color(0xFF9AA3B2);
const Color kLightningLightBackground = Color(0xFFF7F7FB);
const Color kLightningLightBorder = Color(0xFFE5E7EB);
const Color kLightningLightMuted = Color(0xFF6B7280);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  AppLanguage _language = AppLanguage.en;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  void _toggleLanguage() {
    setState(() {
      _language = _language == AppLanguage.en ? AppLanguage.ar : AppLanguage.en;
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
          textDirection:
              _language == AppLanguage.ar ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: HomePage(
        language: _language,
        onToggleLanguage: _toggleLanguage,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class ActiveRequest {
  const ActiveRequest({
    required this.driverName,
    required this.truckType,
    required this.rating,
    required this.etaMinutes,
    required this.distanceKm,
    required this.statusLabel,
  });

  final String driverName;
  final String truckType;
  final double rating;
  final int etaMinutes;
  final double distanceKm;
  final String statusLabel;
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.language,
    required this.onToggleLanguage,
    required this.onToggleTheme,
  });

  final AppLanguage language;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final UserProfile _user = const UserProfile(
    firstName: 'Ahmed',
    lastName: 'Al-Khalifa',
    email: 'a@gmail.com',
    role: 'Customer',
    totalRides: 24,
    totalSpent: '471.250',
    memberSince: 'Jan 2024',
  );

  final List<ActiveRequest> _activeRequests = const [
    ActiveRequest(
      driverName: 'Ahmed Al-Khalifa',
      truckType: 'Flatbed Tow Truck',
      rating: 4.8,
      etaMinutes: 8,
      distanceKm: 3.7,
      statusLabel: 'En Route',
    ),
  ];

  int _tabIndex = 0;

  bool _isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  List<Color> _backgroundGradient(BuildContext context) {
    if (_isDark(context)) {
      return const [
        Color(0xFF0B1220),
        Color(0xFF0E1728),
        Color(0xFF101B31),
      ];
    }
    return const [
      Color(0xFFF7F7FB),
      Color(0xFFF1F4FB),
      Color(0xFFF7F7FB),
    ];
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

  Color _infoPillBackground(BuildContext context) {
    return _isDark(context) ? const Color(0xFF101827) : const Color(0xFFF9FAFB);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.language);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _backgroundGradient(context),
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(context, strings),
                      const SizedBox(height: 20),
                      Text(
                        strings.welcome(_user.firstName),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
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
                      ),
                      const SizedBox(height: 12),
                      _buildActionCard(
                        context,
                        icon: Icons.location_on_outlined,
                        iconColor: const Color(0xFF22C55E),
                        title: strings.text('trackService'),
                        subtitle: strings.text('trackServiceSub'),
                      ),
                      const SizedBox(height: 12),
                      _buildActionCard(
                        context,
                        icon: Icons.attach_money,
                        iconColor: const Color(0xFF60A5FA),
                        title: strings.text('getEstimate'),
                        subtitle: strings.text('getEstimateSub'),
                      ),
                      const SizedBox(height: 18),
                      _buildTabs(context, strings),
                      const SizedBox(height: 16),
                      if (_tabIndex == 0) ...[
                        for (final request in _activeRequests) ...[
                          _buildActiveRequestCard(context, request, strings),
                          const SizedBox(height: 12),
                        ]
                      ] else
                        _buildEmptyState(context, strings),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, AppStrings strings) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: kLightningYellow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.flash_on, color: kLightningNavy),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.text('appName'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                strings.text('dashboard'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                  user: _user,
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
          onPressed: () {},
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
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
                        fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _isDark(context) ? const Color(0xFF1A2336) : const Color(0xFFEFF1F5),
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
    final bool isSelected = _tabIndex == index;
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
                    fontWeight: FontWeight.w600,
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

  Widget _buildActiveRequestCard(
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
                backgroundColor:
                    _isDark(context) ? const Color(0xFF202A3F) : const Color(0xFFE5E7EB),
                child: Text(
                  request.driverName.substring(0, 1),
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
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.truckType,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _mutedColor(context),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: kLightningYellow),
                        const SizedBox(width: 4),
                        Text(
                          request.rating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kLightningYellow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  strings.text('enRoute'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: kLightningNavy,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoPill(
                context,
                icon: Icons.schedule,
                label: strings.text('eta'),
                value: '${request.etaMinutes} min',
              ),
              const SizedBox(width: 12),
              _buildInfoPill(
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

  Widget _buildInfoPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _infoPillBackground(context),
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
                        fontWeight: FontWeight.w600,
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
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 32, color: _mutedColor(context)),
          const SizedBox(height: 8),
          Text(
            strings.text('noHistoryTitle'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.text('noHistoryBody'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mutedColor(context),
                ),
          ),
        ],
      ),
    );
  }
}

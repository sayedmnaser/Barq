import 'package:flutter/material.dart';

const Color kLightningCard = Color(0xFF141B2D);
const Color kLightningBorder = Color(0xFF27314A);
const Color kLightningMuted = Color(0xFF9AA3B2);
const Color kLightningLightBorder = Color(0xFFE5E7EB);
const Color kLightningLightMuted = Color(0xFF6B7280);

enum AppLanguage { en, ar }

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  static const Map<AppLanguage, Map<String, String>> _values = {
    AppLanguage.en: {
      'appName': 'Barq',
      'dashboard': 'Customer Dashboard',
      'settings': 'Settings',
      'logout': 'Logout',
      'welcome': 'Welcome back, {name}!',
      'help': "Need a tow? We're here to help 24/7",
      'requestTow': 'Request Tow',
      'requestTowSub': 'Get help now or schedule for later',
      'trackService': 'Track Service',
      'trackServiceSub': 'Monitor your tow truck in real-time',
      'getEstimate': 'Get Estimate',
      'getEstimateSub': 'Calculate pricing for your route',
      'activeRequests': 'Active Requests',
      'serviceHistory': 'Service History',
      'noHistoryTitle': 'No service history yet',
      'noHistoryBody': 'Completed requests will appear here.',
      'eta': 'ETA',
      'distance': 'Distance',
      'enRoute': 'En Route',
      'profileSettings': 'Profile Settings',
      'manageAccount': 'Manage your account and preferences',
      'appearance': 'Appearance',
      'darkMode': 'Dark mode',
      'language': 'Language',
      'english': 'English',
      'arabic': 'Arabic',
      'accountTab': 'Account',
      'preferencesTab': 'Preferences',
      'paymentTab': 'Payments',
      'totalRides': 'Total Rides',
      'totalSpent': 'Total Spent',
      'memberSince': 'Member Since',
      'accountInfo': 'Account Information',
      'updateInfo': 'Update your personal information',
      'fullName': 'Full Name',
      'emailAddress': 'Email Address',
      'phoneNumber': 'Phone Number',
      'accountType': 'Account Type',
      'preferencesTitle': 'Preferences',
      'customizeExperience': 'Customize your experience',
      'notifications': 'Notifications',
      'emailNotifications': 'Email notifications',
      'smsNotifications': 'SMS notifications',
      'serviceUpdates': 'Service updates',
      'paymentMethods': 'Payment Methods',
      'managePaymentOptions': 'Manage your payment options',
      'defaultLabel': 'Default',
      'addPaymentMethod': 'Add Payment Method',
      'privacy': 'Privacy',
      'shareLocation': 'Share location',
      'showProfile': 'Show profile to other users',
        'requestTowService': 'Request Tow Service',
        'matchSubtitle': "We'll match you with the best driver",
        'quickRequestAvailable': 'Quick Request Available!',
        'quickRequestBody':
          'Ahmed Al-Khalifa is just 1.2 mi away. Select a vehicle type and click "Request This Truck Now" for instant service.',
        'refreshLocation': 'Refresh Location',
        'yourLocation': 'Your Location',
        'closestTruck': 'Closest Truck',
        'availableTrucks': 'Available Trucks',
        'closestAvailable': 'Closest Available',
        'requestThisTruckNow': 'Request This Truck Now',
        'serviceDetails': 'Service Details',
        'serviceDetailsSub': 'Tell us about your towing needs',
        'whenNeedService': 'When do you need service?',
        'immediate': 'Immediate - As soon as possible',
        'scheduleLater': 'Schedule for later',
        'pickupLocation': 'Pickup Location *',
        'destination': 'Destination *',
        'vehicleType': 'Vehicle/Service Type *',
        'additionalDetails': 'Additional Details (Optional)',
        'destinationHint': 'Where should we tow your vehicle?',
        'vehicleTypeHint': 'Select vehicle type',
        'additionalDetailsHint': 'Any special instructions or vehicle details...',
        'aiSmartMatching': 'AI Smart Matching',
        'aiSmartBody':
          'Our AI analyzes location, availability, service history, and ratings to match you with the perfect driver.',
        'whatsIncluded': "What's Included",
        'fastResponse': 'Fast Response',
        'fastResponseSub': 'Average arrival in 15 min',
        'realtimeTracking': 'Real-time Tracking',
        'realtimeTrackingSub': 'Track your driver live on map',
        'professionalService': 'Professional Service',
        'professionalServiceSub': 'Verified & rated drivers',
    },
    AppLanguage.ar: {
      'appName': 'برق',
      'dashboard': 'لوحة العميل',
      'settings': 'الإعدادات',
      'logout': 'تسجيل الخروج',
      'welcome': 'مرحبًا بعودتك، {name}!',
      'help': 'تحتاج سحب؟ نحن هنا للمساعدة على مدار الساعة',
      'requestTow': 'طلب سحب',
      'requestTowSub': 'اطلب المساعدة الآن أو جدولة لاحقًا',
      'trackService': 'تتبع الخدمة',
      'trackServiceSub': 'راقب شاحنة السحب لحظة بلحظة',
      'getEstimate': 'احصل على تقدير',
      'getEstimateSub': 'احسب التكلفة لمسارك',
      'activeRequests': 'الطلبات النشطة',
      'serviceHistory': 'سجل الخدمة',
      'noHistoryTitle': 'لا يوجد سجل خدمة بعد',
      'noHistoryBody': 'ستظهر الطلبات المكتملة هنا.',
      'eta': 'الوقت المتوقع',
      'distance': 'المسافة',
      'enRoute': 'في الطريق',
      'profileSettings': 'إعدادات الملف الشخصي',
      'manageAccount': 'إدارة حسابك وتفضيلاتك',
      'appearance': 'المظهر',
      'darkMode': 'الوضع الداكن',
      'language': 'اللغة',
      'english': 'الإنجليزية',
      'arabic': 'العربية',
      'accountTab': 'الحساب',
      'preferencesTab': 'التفضيلات',
      'paymentTab': 'الدفع',
      'totalRides': 'إجمالي الرحلات',
      'totalSpent': 'إجمالي الإنفاق',
      'memberSince': 'عضو منذ',
      'accountInfo': 'معلومات الحساب',
      'updateInfo': 'حدّث معلوماتك الشخصية',
      'fullName': 'الاسم الكامل',
      'emailAddress': 'البريد الإلكتروني',
      'phoneNumber': 'رقم الهاتف',
      'accountType': 'نوع الحساب',
      'preferencesTitle': 'التفضيلات',
      'customizeExperience': 'خصّص تجربتك',
      'notifications': 'الإشعارات',
      'emailNotifications': 'إشعارات البريد الإلكتروني',
      'smsNotifications': 'إشعارات الرسائل النصية',
      'serviceUpdates': 'تحديثات الخدمة',
      'paymentMethods': 'طرق الدفع',
      'managePaymentOptions': 'إدارة خيارات الدفع',
      'defaultLabel': 'افتراضي',
      'addPaymentMethod': 'إضافة طريقة دفع',
      'privacy': 'الخصوصية',
      'shareLocation': 'مشاركة الموقع',
      'showProfile': 'إظهار الملف الشخصي للمستخدمين الآخرين',
        'requestTowService': 'طلب خدمة السحب',
        'matchSubtitle': 'سنطابقك مع أفضل سائق',
        'quickRequestAvailable': 'طلب سريع متاح!',
        'quickRequestBody':
          'أحمد آل خليفة يبعد 1.2 ميل فقط. اختر نوع المركبة واضغط "اطلب هذه الشاحنة الآن" للخدمة الفورية.',
        'refreshLocation': 'تحديث الموقع',
        'yourLocation': 'موقعك',
        'closestTruck': 'أقرب شاحنة',
        'availableTrucks': 'الشاحنات المتاحة',
        'closestAvailable': 'الأقرب المتاح',
        'requestThisTruckNow': 'اطلب هذه الشاحنة الآن',
        'serviceDetails': 'تفاصيل الخدمة',
        'serviceDetailsSub': 'أخبرنا باحتياجات السحب الخاصة بك',
        'whenNeedService': 'متى تحتاج الخدمة؟',
        'immediate': 'فوري - بأسرع وقت ممكن',
        'scheduleLater': 'جدولة لاحقًا',
        'pickupLocation': 'موقع الالتقاط *',
        'destination': 'الوجهة *',
        'vehicleType': 'نوع المركبة/الخدمة *',
        'additionalDetails': 'تفاصيل إضافية (اختياري)',
        'destinationHint': 'إلى أين ترغب بسحب مركبتك؟',
        'vehicleTypeHint': 'اختر نوع المركبة',
        'additionalDetailsHint': 'أي تعليمات خاصة أو تفاصيل عن المركبة...',
        'aiSmartMatching': 'مطابقة ذكية بالذكاء الاصطناعي',
        'aiSmartBody':
          'يقوم الذكاء الاصطناعي بتحليل الموقع والتوفر وسجل الخدمة والتقييمات لمطابقتك مع السائق الأنسب.',
        'whatsIncluded': 'ما الذي يتضمنه',
        'fastResponse': 'استجابة سريعة',
        'fastResponseSub': 'متوسط الوصول خلال 15 دقيقة',
        'realtimeTracking': 'تتبع لحظي',
        'realtimeTrackingSub': 'تتبع السائق مباشرة على الخريطة',
        'professionalService': 'خدمة احترافية',
        'professionalServiceSub': 'سائقون موثقون ومقيّمون',
    },
  };

  String text(String key) => _values[language]?[key] ?? key;

  String welcome(String name) => text('welcome').replaceAll('{name}', name);
}

class UserProfile {
  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.totalRides,
    required this.totalSpent,
    required this.memberSince,
    this.phoneNumber,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final int totalRides;
  final String totalSpent;
  final String memberSince;
  final String? phoneNumber;

  String get fullName => '$firstName $lastName'.trim();
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.user,
    required this.language,
    required this.isDark,
    required this.onToggleTheme,
    required this.onToggleLanguage,
  });

  final UserProfile user;
  final AppLanguage language;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLanguage;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppLanguage _language;
  late bool _isDark;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _serviceUpdates = true;
  bool _shareLocation = true;
  bool _showProfile = true;

  @override
  void initState() {
    super.initState();
    _language = widget.language;
    _isDark = widget.isDark;
  }

  void _handleThemeToggle(bool value) {
    setState(() {
      _isDark = value;
    });
    widget.onToggleTheme();
  }

  void _handleLanguageToggle(AppLanguage language) {
    if (_language == language) {
      return;
    }
    setState(() {
      _language = language;
    });
    widget.onToggleLanguage();
  }

  bool _isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color _cardColor(BuildContext context) {
    return _isDarkMode(context) ? kLightningCard : Colors.white;
  }

  Color _borderColor(BuildContext context) {
    return _isDarkMode(context) ? kLightningBorder : kLightningLightBorder;
  }

  Color _mutedColor(BuildContext context) {
    return _isDarkMode(context) ? kLightningMuted : kLightningLightMuted;
  }

  Color _softSurface(BuildContext context) {
    return _isDarkMode(context) ? const Color(0xFF1A2336) : const Color(0xFFEFF1F5);
  }

  Color _fieldSurface(BuildContext context) {
    return _isDarkMode(context) ? const Color(0xFF101827) : const Color(0xFFF9FAFB);
  }

  Color _chipSurface(BuildContext context) {
    return _isDarkMode(context) ? const Color(0xFF202A3F) : const Color(0xFFE5E7EB);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(_language);
    final muted = _mutedColor(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.text('profileSettings')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                strings.text('manageAccount'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: muted,
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _profileCard(context, strings, muted),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                height: 44,
                decoration: BoxDecoration(
                  color: _softSurface(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _borderColor(context)),
                ),
                child: TabBar(
                  labelColor:
                      _isDarkMode(context) ? Colors.white : const Color(0xFF111827),
                  unselectedLabelColor: muted,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: _cardColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _borderColor(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: _isDarkMode(context) ? 0.2 : 0.08,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  tabs: [
                    Tab(text: strings.text('accountTab')),
                    Tab(text: strings.text('preferencesTab')),
                    Tab(text: strings.text('paymentTab')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _buildAccountTab(context, strings, muted),
                  _buildPreferencesTab(context, strings, muted),
                  _buildPaymentTab(context, strings, muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(
    BuildContext context,
    AppStrings strings,
    Color? muted,
  ) {
    final user = widget.user;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: _chipSurface(context),
            child: Text(
              user.firstName.substring(0, 1),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user.fullName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            user.email,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: muted,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _chipSurface(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: _borderColor(context)),
          const SizedBox(height: 12),
          _statRow(
            context,
            icon: Icons.directions_car_outlined,
            iconColor: const Color(0xFF2F6BFF),
            label: strings.text('totalRides'),
            value: user.totalRides.toString(),
            muted: muted,
          ),
          const SizedBox(height: 8),
          _statRow(
            context,
            icon: Icons.trending_up,
            iconColor: const Color(0xFF16A34A),
            label: strings.text('totalSpent'),
            value: user.totalSpent,
            muted: muted,
          ),
          const SizedBox(height: 8),
          _statRow(
            context,
            icon: Icons.verified_outlined,
            iconColor: const Color(0xFF7C3AED),
            label: strings.text('memberSince'),
            value: user.memberSince,
            muted: muted,
          ),
        ],
      ),
    );
  }

  Widget _statRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? muted,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: muted,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildAccountTab(
    BuildContext context,
    AppStrings strings,
    Color? muted,
  ) {
    final user = widget.user;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _sectionCard(
          context,
          title: strings.text('accountInfo'),
          leadingIcon: Icons.badge_outlined,
          subtitle: strings.text('updateInfo'),
          children: [
            _infoTile(
              context,
              label: strings.text('fullName'),
              value: user.fullName,
              icon: Icons.person_outline,
              muted: muted,
            ),
            _infoTile(
              context,
              label: strings.text('emailAddress'),
              value: user.email,
              icon: Icons.mail_outline,
              muted: muted,
            ),
            _infoTile(
              context,
              label: strings.text('phoneNumber'),
              value: user.phoneNumber ?? '--',
              icon: Icons.call_outlined,
              muted: muted,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          context,
          title: strings.text('accountType'),
          leadingIcon: Icons.verified_user_outlined,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(user.role),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreferencesTab(
    BuildContext context,
    AppStrings strings,
    Color? muted,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _sectionCard(
          context,
          title: strings.text('preferencesTitle'),
          leadingIcon: Icons.tune,
          subtitle: strings.text('customizeExperience'),
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isDark,
              onChanged: _handleThemeToggle,
              secondary: const Icon(Icons.brightness_6_outlined),
              title: Text(strings.text('darkMode')),
            ),
            const Divider(height: 16),
            Row(
              children: [
                const Icon(Icons.language_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  strings.text('language'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<AppLanguage>(
              segments: [
                ButtonSegment(
                  value: AppLanguage.en,
                  label: Text(strings.text('english')),
                ),
                ButtonSegment(
                  value: AppLanguage.ar,
                  label: Text(strings.text('arabic')),
                ),
              ],
              selected: {_language},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  _handleLanguageToggle(selection.first);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          context,
          title: strings.text('notifications'),
          leadingIcon: Icons.notifications_outlined,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _emailNotifications,
              onChanged: (value) {
                setState(() {
                  _emailNotifications = value;
                });
              },
              secondary: const Icon(Icons.mail_outline),
              title: Text(strings.text('emailNotifications')),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _smsNotifications,
              onChanged: (value) {
                setState(() {
                  _smsNotifications = value;
                });
              },
              secondary: const Icon(Icons.sms_outlined),
              title: Text(strings.text('smsNotifications')),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _serviceUpdates,
              onChanged: (value) {
                setState(() {
                  _serviceUpdates = value;
                });
              },
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text(strings.text('serviceUpdates')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          context,
          title: strings.text('privacy'),
          leadingIcon: Icons.lock_outline,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _shareLocation,
              onChanged: (value) {
                setState(() {
                  _shareLocation = value;
                });
              },
              secondary: const Icon(Icons.location_on_outlined),
              title: Text(strings.text('shareLocation')),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _showProfile,
              onChanged: (value) {
                setState(() {
                  _showProfile = value;
                });
              },
              secondary: const Icon(Icons.visibility_outlined),
              title: Text(strings.text('showProfile')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentTab(
    BuildContext context,
    AppStrings strings,
    Color? muted,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _sectionCard(
          context,
          title: strings.text('paymentMethods'),
          leadingIcon: Icons.credit_card,
          subtitle: strings.text('managePaymentOptions'),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _fieldSurface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor(context)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.credit_card, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '•••• •••• •••• 4242',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Expires 12/26',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _softSurface(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      strings.text('defaultLabel'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: Text(strings.text('addPaymentMethod')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? muted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: muted,
                ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _fieldSurface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _softSurface(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: muted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    IconData? leadingIcon,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: _isDarkMode(context) ? 0.2 : 0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leadingIcon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _softSurface(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(leadingIcon, size: 18),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _mutedColor(context),
                  ),
            ),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

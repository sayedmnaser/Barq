import 'package:flutter/material.dart';
import 'settings.dart';

class RequestTowPage extends StatefulWidget {
  const RequestTowPage({super.key});

  @override
  State<RequestTowPage> createState() => _RequestTowPageState();
}

class _RequestTowPageState extends State<RequestTowPage> {
  int _serviceTiming = 0;

  @override
  Widget build(BuildContext context) {
    final language = Directionality.of(context) == TextDirection.rtl
        ? AppLanguage.ar
        : AppLanguage.en;
    final strings = AppStrings(language);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('requestTowService')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              strings.text('matchSubtitle'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(
                          alpha: 0.7,
                        ),
                  ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuickBanner(context, strings),
            const SizedBox(height: 16),
            _buildMapCard(context, strings),
            const SizedBox(height: 16),
            _buildServiceDetails(context, strings),
            const SizedBox(height: 16),
            _buildAiCard(context, strings),
            const SizedBox(height: 16),
            _buildIncludedCard(context, strings),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickBanner(BuildContext context, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.flash_on, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.text('quickRequestAvailable'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.text('quickRequestBody'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF166534),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(BuildContext context, AppStrings strings) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFFE6F4FF), Color(0xFFEFFAF0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 16,
            left: 16,
            child: _legendCard(context, strings),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(strings.text('refreshLocation')),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF111827),
              ),
            ),
          ),
          Positioned(
            left: 120,
            top: 70,
            child: _mapPin(color: const Color(0xFF16A34A)),
          ),
          Positioned(
            right: 80,
            top: 90,
            child: _mapPin(color: const Color(0xFFF97316)),
          ),
          Positioned(
            right: 120,
            top: 120,
            child: _mapPin(color: const Color(0xFF2563EB)),
          ),
          Positioned(
            left: 40,
            top: 120,
            right: 40,
            child: _driverCard(context, strings),
          ),
        ],
      ),
    );
  }

  Widget _legendCard(BuildContext context, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legendRow(const Color(0xFF2563EB), strings.text('yourLocation')),
          const SizedBox(height: 6),
          _legendRow(const Color(0xFF16A34A), strings.text('closestTruck')),
          const SizedBox(height: 6),
          _legendRow(const Color(0xFFF97316), strings.text('availableTrucks')),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _mapPin({required Color color}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.local_shipping, color: Colors.white, size: 16),
    );
  }

  Widget _driverCard(BuildContext context, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF22C55E), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.text('closestAvailable'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B7280),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ahmed Al-Khalifa',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '5 min',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text('1.2 mi away', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 12),
              const Icon(Icons.star, size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 4),
              Text('4.9', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.flash_on, size: 18),
              label: Text(strings.text('requestThisTruckNow')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDetails(BuildContext context, AppStrings strings) {
    return _sectionCard(
      context,
      title: strings.text('serviceDetails'),
      subtitle: strings.text('serviceDetailsSub'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.text('whenNeedService'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(strings.text('immediate'))),
              ButtonSegment(value: 1, label: Text(strings.text('scheduleLater'))),
            ],
            selected: {_serviceTiming},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                setState(() {
                  _serviceTiming = selection.first;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          _fieldLabel(context, strings.text('pickupLocation')),
          const SizedBox(height: 6),
          _fieldChip(context, 'Manama, Bahrain'),
          const SizedBox(height: 12),
          _fieldLabel(context, strings.text('destination')),
          const SizedBox(height: 6),
          _fieldChip(context, strings.text('destinationHint')),
          const SizedBox(height: 12),
          _fieldLabel(context, strings.text('vehicleType')),
          const SizedBox(height: 6),
          _fieldChip(context, strings.text('vehicleTypeHint')),
          const SizedBox(height: 12),
          _fieldLabel(context, strings.text('additionalDetails')),
          const SizedBox(height: 6),
          _fieldChip(context, strings.text('additionalDetailsHint')),
        ],
      ),
    );
  }

  Widget _buildAiCard(BuildContext context, AppStrings strings) {
    return _sectionCard(
      context,
      title: strings.text('aiSmartMatching'),
      subtitle: strings.text('aiSmartBody'),
      leading: const Icon(Icons.auto_awesome, color: Color(0xFF2563EB)),
    );
  }

  Widget _buildIncludedCard(BuildContext context, AppStrings strings) {
    return _sectionCard(
      context,
      title: strings.text('whatsIncluded'),
      child: Column(
        children: [
          _includedRow(
            context,
            icon: Icons.bolt,
            title: strings.text('fastResponse'),
            subtitle: strings.text('fastResponseSub'),
          ),
          const SizedBox(height: 10),
          _includedRow(
            context,
            icon: Icons.location_on_outlined,
            title: strings.text('realtimeTracking'),
            subtitle: strings.text('realtimeTrackingSub'),
          ),
          const SizedBox(height: 10),
          _includedRow(
            context,
            icon: Icons.verified_outlined,
            title: strings.text('professionalService'),
            subtitle: strings.text('professionalServiceSub'),
          ),
        ],
      ),
    );
  }

  Widget _includedRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(
                            alpha: 0.7,
                          ),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? child,
    Widget? leading,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              if (leading != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: leading),
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
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(
                          alpha: 0.7,
                        ),
                  ),
            ),
          ],
          if (child != null) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _fieldChip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF9CA3AF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

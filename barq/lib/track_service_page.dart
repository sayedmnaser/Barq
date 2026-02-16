import 'package:flutter/material.dart';

class TrackServicePage extends StatelessWidget {
  const TrackServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Track Your Service',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Real-time service tracking',
              style: textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MapCard(textTheme: textTheme),
            const SizedBox(height: 16),
            _ServiceProgressCard(textTheme: textTheme),
            const SizedBox(height: 16),
            _LocationDetailsCard(textTheme: textTheme),
            const SizedBox(height: 16),
            _DriverCard(textTheme: textTheme),
            const SizedBox(height: 16),
            _EtaCard(textTheme: textTheme),
            const SizedBox(height: 16),
            _CostCard(textTheme: textTheme),
            const SizedBox(height: 16),
            _HelpCard(textTheme: textTheme),
          ],
        ),
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD9E8F7), Color(0xFFDDF5E7)],
        ),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 32,
            left: 64,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFF2563EB),
              child: Icon(Icons.navigation, color: Colors.white),
            ),
          ),
          const Positioned(
            top: 48,
            right: 100,
            child: Icon(Icons.location_on_outlined, size: 64, color: Color(0xFF2563EB)),
          ),
          Positioned(
            right: 12,
            bottom: 58,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on, color: Colors.white),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Live Map View',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Driver is 0.2 miles away',
                  style: textTheme.bodyLarge?.copyWith(color: const Color(0xFF475569)),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'ETA: 0 minutes',
                    style: textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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
}

class _ServiceProgressCard extends StatelessWidget {
  const _ServiceProgressCard({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Service Progress', style: textTheme.titleLarge),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 0.52,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF111827)),
            ),
          ),
          const SizedBox(height: 16),
          _ProgressRow(label: 'Request Received', time: '2:30 PM', done: true),
          const SizedBox(height: 12),
          _ProgressRow(label: 'Driver Assigned', time: '2:32 PM', done: true),
          const SizedBox(height: 12),
          _ProgressRow(label: 'Driver En Route', time: 'In progress', done: false),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.time,
    required this.done,
  });

  final String label;
  final String time;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
        Text(
          time,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: done ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

class _LocationDetailsCard extends StatelessWidget {
  const _LocationDetailsCard({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Location Details', style: textTheme.titleLarge),
          const SizedBox(height: 16),
          _LocationRow(
            icon: Icons.location_on_outlined,
            iconBg: const Color(0xFFD1FAE5),
            iconColor: const Color(0xFF16A34A),
            title: 'Pickup Location',
            subtitle: 'Seef District, Manama',
          ),
          const Divider(height: 26),
          _LocationRow(
            icon: Icons.location_on_outlined,
            iconBg: const Color(0xFFFEE2E2),
            iconColor: Colors.red,
            title: 'Destination',
            subtitle: 'Auto Repair - Sitra Industrial Area',
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Driver', style: textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('A', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ahmed Al-Khalifa',
                      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFACC15), size: 18),
                        const SizedBox(width: 4),
                        Text('4.8', style: textTheme.titleMedium),
                        const SizedBox(width: 4),
                        Text(
                          '(1247 rides)',
                          style: textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _KeyValueRow(label: 'Vehicle', value: 'Flatbed Tow Truck #12'),
          const SizedBox(height: 8),
          _KeyValueRow(label: 'License Plate', value: 'TOW-2481'),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.call_outlined),
            label: const Text('Call Driver'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Send Message'),
          ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF475569),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _EtaCard extends StatelessWidget {
  const _EtaCard({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, color: Color(0xFF2563EB)),
              const SizedBox(width: 10),
              Text('Estimated Arrival', style: textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '0 min',
              style: textTheme.displaySmall?.copyWith(
                color: const Color(0xFF2563EB),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Driver is on the way',
              style: textTheme.bodyLarge?.copyWith(color: const Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CostCard extends StatelessWidget {
  const _CostCard({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Service Cost', style: textTheme.titleLarge),
          const SizedBox(height: 16),
          const _KeyValueRow(label: 'Base fare', value: '50.000 BHD'),
          const SizedBox(height: 10),
          const _KeyValueRow(label: 'Distance (6.2 mi)', value: '25.000 BHD'),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '75.000 BHD',
                style: textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF16A34A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Payment will be processed after service completion',
            style: textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.help_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Text('Need Help?', style: textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: child,
    );
  }
}
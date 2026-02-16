import 'package:flutter/material.dart';

import 'settings.dart';

enum EstimateVehicleType { sedan, suv, motorcycle, flatbed }

class GetEstimatePage extends StatefulWidget {
  const GetEstimatePage({super.key, required this.language});

  final AppLanguage language;

  @override
  State<GetEstimatePage> createState() => _GetEstimatePageState();
}

class _GetEstimatePageState extends State<GetEstimatePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  EstimateVehicleType _vehicleType = EstimateVehicleType.sedan;
  double _distanceKm = 8;
  bool _nightService = false;

  double _baseFare = 12;
  double _distanceFare = 9.6;
  double _serviceFee = 2.0;
  double _surcharge = 0;
  double _total = 23.6;

  @override
  void initState() {
    super.initState();
    _pickupController.text = 'Seef District, Manama';
    _destinationController.text = 'Sitra Industrial Area';
    _recalculate();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _recalculate() {
    const Map<EstimateVehicleType, double> vehicleBaseFare = {
      EstimateVehicleType.sedan: 12,
      EstimateVehicleType.suv: 15,
      EstimateVehicleType.motorcycle: 10,
      EstimateVehicleType.flatbed: 22,
    };

    const Map<EstimateVehicleType, double> perKmRate = {
      EstimateVehicleType.sedan: 1.2,
      EstimateVehicleType.suv: 1.45,
      EstimateVehicleType.motorcycle: 0.95,
      EstimateVehicleType.flatbed: 1.85,
    };

    final double baseFare = vehicleBaseFare[_vehicleType] ?? 12;
    final double distanceFare = _distanceKm * (perKmRate[_vehicleType] ?? 1.2);
    const double serviceFee = 2.0;
    final double subtotal = baseFare + distanceFare + serviceFee;
    final double surcharge = _nightService ? subtotal * 0.2 : 0.0;
    final double total = subtotal + surcharge;

    setState(() {
      _baseFare = baseFare;
      _distanceFare = distanceFare;
      _serviceFee = serviceFee;
      _surcharge = surcharge;
      _total = total;
    });
  }

  String _vehicleTypeLabel(AppStrings strings, EstimateVehicleType type) {
    switch (type) {
      case EstimateVehicleType.sedan:
        return strings.text('estimateSedan');
      case EstimateVehicleType.suv:
        return strings.text('estimateSuv');
      case EstimateVehicleType.motorcycle:
        return strings.text('estimateMotorcycle');
      case EstimateVehicleType.flatbed:
        return strings.text('estimateFlatbed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.language);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('getEstimate')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.text('estimateTitle'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.text('estimateSubtitle'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _pickupController,
                          decoration: InputDecoration(
                            labelText: strings.text('pickupLocation'),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return strings.text('requiredField');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _destinationController,
                          decoration: InputDecoration(
                            labelText: strings.text('destination'),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return strings.text('requiredField');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<EstimateVehicleType>(
                          value: _vehicleType,
                          decoration: InputDecoration(
                            labelText: strings.text('vehicleType'),
                            border: const OutlineInputBorder(),
                          ),
                          items: EstimateVehicleType.values
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(_vehicleTypeLabel(strings, type)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _vehicleType = value;
                            });
                            _recalculate();
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${strings.text('estimateDistance')}: ${_distanceKm.toStringAsFixed(1)} km',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _distanceKm,
                          min: 1,
                          max: 120,
                          divisions: 119,
                          label: _distanceKm.toStringAsFixed(1),
                          onChanged: (value) {
                            setState(() {
                              _distanceKm = value;
                            });
                            _recalculate();
                          },
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _nightService,
                          title: Text(strings.text('estimateNightService')),
                          subtitle: Text(strings.text('estimateNightServiceSub')),
                          onChanged: (value) {
                            setState(() {
                              _nightService = value;
                            });
                            _recalculate();
                          },
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                _recalculate();
                              }
                            },
                            child: Text(strings.text('estimateCalculate')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.text('estimateResultTitle'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _EstimateRow(
                    label: strings.text('estimateBaseFare'),
                    value: _baseFare,
                  ),
                  const SizedBox(height: 8),
                  _EstimateRow(
                    label: '${strings.text('estimateDistanceFare')} (${_distanceKm.toStringAsFixed(1)} km)',
                    value: _distanceFare,
                  ),
                  const SizedBox(height: 8),
                  _EstimateRow(
                    label: strings.text('estimateServiceFee'),
                    value: _serviceFee,
                  ),
                  if (_surcharge > 0) ...[
                    const SizedBox(height: 8),
                    _EstimateRow(
                      label: strings.text('estimateNightSurcharge'),
                      value: _surcharge,
                    ),
                  ],
                  const Divider(height: 24),
                  _EstimateRow(
                    label: strings.text('estimateTotal'),
                    value: _total,
                    isTotal: true,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    strings.text('estimateDisclaimer'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
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
}

class _EstimateRow extends StatelessWidget {
  const _EstimateRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final double value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final style = isTotal
        ? Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          )
        : Theme.of(context).textTheme.bodyLarge;

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(
          '${value.toStringAsFixed(3)} BHD',
          style: style?.copyWith(
            color: isTotal ? const Color(0xFF16A34A) : null,
          ),
        ),
      ],
    );
  }
}
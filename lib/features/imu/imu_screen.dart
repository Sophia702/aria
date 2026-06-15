import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/imu_reading.dart';
import '../../providers/providers.dart';
import '../../services/sensors/arduino_ble_service.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class ImuScreen extends ConsumerStatefulWidget {
  const ImuScreen({super.key});

  @override
  ConsumerState<ImuScreen> createState() => _ImuScreenState();
}

class _ImuScreenState extends ConsumerState<ImuScreen> {
  static const _kBuf = 100;

  final _accX = <double>[];
  final _accY = <double>[];
  final _accZ = <double>[];
  final _gyroX = <double>[];
  final _gyroY = <double>[];
  final _gyroZ = <double>[];

  ImuReading? _latest;
  StreamSubscription<ImuReading>? _imuSub;
  StreamSubscription<void>? _changeSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final svc = ref.read(arduinoBleProvider);
      _imuSub = svc.readings.listen(_onReading);
      _changeSub = svc.onChange.listen((_) { if (mounted) setState(() {}); });
    });
  }

  void _onReading(ImuReading r) {
    if (!mounted) return;
    setState(() {
      _latest = r;
      _push(_accX, r.accX);
      _push(_accY, r.accY);
      _push(_accZ, r.accZ);
      _push(_gyroX, r.gyroX);
      _push(_gyroY, r.gyroY);
      _push(_gyroZ, r.gyroZ);
    });
  }

  void _push(List<double> buf, double v) {
    buf.add(v);
    if (buf.length > _kBuf) buf.removeAt(0);
  }

  @override
  void dispose() {
    _imuSub?.cancel();
    _changeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = ref.read(arduinoBleProvider);

    return Scaffold(
      body: AppTheme.pageBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(ble: ble),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  child: ble.state == ArduinoBleState.connected
                      ? _ConnectedBody(
                          accX: _accX,
                          accY: _accY,
                          accZ: _accZ,
                          gyroX: _gyroX,
                          gyroY: _gyroY,
                          gyroZ: _gyroZ,
                          latest: _latest,
                          ble: ble,
                        )
                      : _DisconnectedBody(ble: ble),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.ble});
  final ArduinoBleService ble;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs, AppSpacing.sm, AppSpacing.lg, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.ink, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text('IMU', style: AppType.h1),
          const Spacer(),
          if (ble.state == ArduinoBleState.scanning ||
              ble.state == ArduinoBleState.connecting)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Disconnected / scan UI ────────────────────────────────────────────────────

class _DisconnectedBody extends StatelessWidget {
  const _DisconnectedBody({required this.ble});
  final ArduinoBleService ble;

  @override
  Widget build(BuildContext context) {
    final scanning = ble.state == ArduinoBleState.scanning;
    final connecting = ble.state == ArduinoBleState.connecting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Error banner
        if (ble.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFFF5E4E4),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.notConnected, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    ble.errorMessage!,
                    style: AppType.label.copyWith(
                        color: AppColors.notConnected, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Scan card
        Container(
          decoration: AppTheme.cardDecoration(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: const Icon(Icons.bluetooth_searching_rounded,
                    color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                scanning ? 'Scanning…' : 'Connect to Arduino',
                style: AppType.h2.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Make sure your Arduino Nano 33 BLE is powered on and running the IMU BLE sketch.',
                style: AppType.label.copyWith(
                    color: AppColors.inkSoft, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: _GradientButton(
                  label: scanning ? 'Stop scan' : 'Scan for devices',
                  onTap: scanning
                      ? () => ble.stopScan()
                      : () => ble.startScan(),
                ),
              ),
            ],
          ),
        ),

        // Device list
        if (ble.scanResults.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: AppTheme.cardDecoration(),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                  child: Text('NEARBY DEVICES', style: AppType.label),
                ),
                for (var i = 0; i < ble.scanResults.length; i++) ...[
                  if (i > 0)
                    const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.lineSoft),
                  _DeviceRow(
                    result: ble.scanResults[i],
                    connecting: connecting,
                    onTap: connecting
                        ? null
                        : () => ble.connect(ble.scanResults[i].device),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow(
      {required this.result, required this.connecting, this.onTap});
  final ScanResult result;
  final bool connecting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : 'Unknown device';
    final rssi = result.rssi;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Icon(Icons.bluetooth_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: AppType.h2.copyWith(fontSize: 15)),
                  Text(
                    '$rssi dBm',
                    style: AppType.label.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            connecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.chevron_right_rounded,
                    color: AppColors.inkFaint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Connected / live-data UI ──────────────────────────────────────────────────

class _ConnectedBody extends StatelessWidget {
  const _ConnectedBody({
    required this.accX,
    required this.accY,
    required this.accZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.latest,
    required this.ble,
  });

  final List<double> accX, accY, accZ;
  final List<double> gyroX, gyroY, gyroZ;
  final ImuReading? latest;
  final ArduinoBleService ble;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Device status row
        Container(
          decoration: AppTheme.cardDecoration(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: const Icon(Icons.developer_board_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ble.connectedName ?? 'Arduino Nano 33 BLE',
                      style: AppType.h2.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text('Streaming IMU data', style: AppType.label),
                  ],
                ),
              ),
              _StatusChip(
                label: 'Live',
                color: AppColors.connected,
                bg: AppColors.okSoft,
                icon: Icons.circle,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Accelerometer chart
        _ImuChart(
          label: 'ACCELEROMETER',
          unit: 'g',
          xData: accX,
          yData: accY,
          zData: accZ,
        ),

        const SizedBox(height: AppSpacing.sm),

        // Acc numeric readout
        _ReadoutRow(
          xVal: latest?.accX,
          yVal: latest?.accY,
          zVal: latest?.accZ,
          unit: 'g',
        ),

        const SizedBox(height: AppSpacing.md),

        // Gyroscope chart
        _ImuChart(
          label: 'GYROSCOPE',
          unit: '°/s',
          xData: gyroX,
          yData: gyroY,
          zData: gyroZ,
        ),

        const SizedBox(height: AppSpacing.sm),

        // Gyro numeric readout
        _ReadoutRow(
          xVal: latest?.gyroX,
          yVal: latest?.gyroY,
          zVal: latest?.gyroZ,
          unit: '°/s',
        ),

        const SizedBox(height: AppSpacing.lg),

        // Disconnect button
        OutlinedButton.icon(
          onPressed: () => ble.disconnect(),
          icon: const Icon(Icons.bluetooth_disabled_rounded, size: 16),
          label: const Text('Disconnect'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.notConnected,
            side: const BorderSide(color: Color(0xFFD9B5B5)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            textStyle: const TextStyle(
              fontFamily: kFontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Chart widget ──────────────────────────────────────────────────────────────

class _ImuChart extends StatelessWidget {
  const _ImuChart({
    required this.label,
    required this.unit,
    required this.xData,
    required this.yData,
    required this.zData,
  });

  final String label, unit;
  final List<double> xData, yData, zData;

  static const int _kSize = 100;
  static const _colX = Color(0xFF4E9A57);
  static const _colY = Color(0xFF164D3C);
  static const _colZ = Color(0xFF8E3E48);

  List<FlSpot> _spots(List<double> data) {
    final offset = _kSize - data.length;
    return List.generate(
      data.length,
      (i) => FlSpot((offset + i).toDouble(), data[i]),
    );
  }

  LineChartBarData _bar(List<double> data, Color color) => LineChartBarData(
        spots: _spots(data),
        color: color,
        barWidth: 1.5,
        isCurved: false,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      );

  @override
  Widget build(BuildContext context) {
    final all = [...xData, ...yData, ...zData];
    double minY = all.isEmpty ? -1 : all.reduce(min) - 0.5;
    double maxY = all.isEmpty ? 1 : all.reduce(max) + 0.5;
    if ((maxY - minY) < 1) {
      final mid = (maxY + minY) / 2;
      minY = mid - 0.5;
      maxY = mid + 0.5;
    }

    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppType.label),
              const Spacer(),
              _LegendDot(label: 'X', color: _colX),
              const SizedBox(width: AppSpacing.sm),
              _LegendDot(label: 'Y', color: _colY),
              const SizedBox(width: AppSpacing.sm),
              _LegendDot(label: 'Z', color: _colZ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (_kSize - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  _bar(xData, _colX),
                  _bar(yData, _colY),
                  _bar(zData, _colZ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontFamily: kFontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
          ),
        ),
      ],
    );
  }
}

// ── Numeric readout row ───────────────────────────────────────────────────────

class _ReadoutRow extends StatelessWidget {
  const _ReadoutRow({
    required this.xVal,
    required this.yVal,
    required this.zVal,
    required this.unit,
  });

  final double? xVal, yVal, zVal;
  final String unit;

  String _fmt(double? v) => v == null ? '—' : v.toStringAsFixed(3);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Val(axis: 'X', value: _fmt(xVal), unit: unit, color: const Color(0xFF4E9A57)),
        _Val(axis: 'Y', value: _fmt(yVal), unit: unit, color: AppColors.primary),
        _Val(axis: 'Z', value: _fmt(zVal), unit: unit, color: AppColors.accent),
      ],
    );
  }
}

class _Val extends StatelessWidget {
  const _Val({
    required this.axis,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String axis, value, unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          '$axis  $unit',
          style: AppType.label.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.bg,
    required this.icon,
  });

  final String label;
  final Color color, bg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 8),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppType.label.copyWith(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDeep],
          ),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        alignment: Alignment.center,
        child: Text(label, style: AppType.button),
      ),
    );
  }
}

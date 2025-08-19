import 'dart:async';
import 'package:flutter/material.dart';

import '../../app_bottom_nav.dart';
import '../../ble/ble_manager.dart';

class WatchConnectPage extends StatefulWidget {
  const WatchConnectPage({super.key});

  @override
  State<WatchConnectPage> createState() => _WatchConnectPageState();
}

class _WatchConnectPageState extends State<WatchConnectPage> {
  bool _connecting = false;
  DateTime? _lastUpdate;

  // 최근 60초 심박 히스토리 (timestamp, bpm)
  final List<_HrPoint> _history = <_HrPoint>[];
  late final VoidCallback _hrListener;

  Timer? _uiTicker;

  @override
  void initState() {
    super.initState();
    _autoConnectOnce();

    // ValueListenable을 구독해서 history에 누적
    _hrListener = () {
      final hr = BleManager.I.heartRate.value;
      if (hr != null && hr > 0) {
        _pushHeart(hr);
      }
    };
    BleManager.I.heartRate.addListener(_hrListener);

    // 500ms마다 UI 리드로우(그래프가 부드럽게 이동)
    _uiTicker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {}); // 그래프의 X축(now 기반) 이동 반영
    });
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    BleManager.I.heartRate.removeListener(_hrListener);
    super.dispose();
  }

  void _pushHeart(int bpm) {
    final now = DateTime.now();
    _lastUpdate = now;
    _history.add(_HrPoint(now, bpm));
    // 60초 윈도우 유지
    final cutoff = now.subtract(const Duration(seconds: 60));
    while (_history.isNotEmpty && _history.first.t.isBefore(cutoff)) {
      _history.removeAt(0);
    }
    if (mounted) setState(() {});
  }

  Future<void> _autoConnectOnce() async {
    if (BleManager.I.isConnected.value) return;
    setState(() => _connecting = true);
    try {
      final ok = await BleManager.I.prepare();
      if (ok) {
        await BleManager.I.scanAndConnect(containsName: "Watch");
        // 연결되면 데이터 새로고침 한 번
        if (BleManager.I.isConnected.value) {
          unawaited(BleManager.I.refresh().catchError((_) {}));
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('블루투스 권한/설정을 확인해 주세요.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('자동 연결 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _manualConnect() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      final ok = await BleManager.I.prepare();
      if (ok) {
        await BleManager.I.scanAndConnect(containsName: "Watch");
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('블루투스 권한/설정을 확인해 주세요.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('연결 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _refresh() async {
    try {
      await BleManager.I.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('심박 데이터를 새로고침했어요.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('새로고침 실패: $e')),
      );
    }
  }

  String _statusText(bool connected) {
    if (connected) return '워치 연결됨';
    return _connecting ? '연결 시도 중…' : '연결 필요';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: BleManager.I.isConnected,
          builder: (context, connected, _) {
            final hr = BleManager.I.heartRate.value ?? 0;
            return Column(
              children: [
                _Header(title: '심박수', subtitle: _statusText(connected)),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: _HeartPanel(
                      bpm: connected ? hr : 0,
                      connected: connected,
                      loading: _connecting,
                      lastUpdate: _lastUpdate,
                      onRefresh: connected ? _refresh : null,
                      history: _history,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: connected || _connecting ? null : _manualConnect,
                          icon: _connecting
                              ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.bluetooth_searching),
                          label: Text(_connecting ? '연결 중…' : '워치에 연결'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: connected ? BleManager.I.disconnect : null,
                          icon: const Icon(Icons.link_off),
                          label: const Text('연결 해제'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }
}

/* -------------------- 위젯 -------------------- */

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Theme.of(context).colorScheme.primary.withOpacity(.10),
            ),
            child: Text(subtitle, style: t.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _HeartPanel extends StatelessWidget {
  const _HeartPanel({
    required this.bpm,
    required this.connected,
    required this.loading,
    required this.lastUpdate,
    required this.onRefresh,
    required this.history,
  });

  final int bpm;
  final bool connected;
  final bool loading;
  final DateTime? lastUpdate;
  final VoidCallback? onRefresh;
  final List<_HrPoint> history;

  String _fmtAgo(DateTime? t) {
    if (t == null) return '—';
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 5) return '방금 전';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    return '${diff.inHours}시간 전';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(.2)),
        boxShadow: [
          BoxShadow(
            blurRadius: 28,
            spreadRadius: -6,
            offset: const Offset(0, 14),
            color: Colors.black.withOpacity(.06),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 아이콘 + 숫자
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withOpacity(.12),
            ),
            child: const Icon(Icons.favorite, size: 36),
          ),
          const SizedBox(height: 14),
          Text(
            connected ? '현재 심박수' : (loading ? '연결 중…' : '워치를 연결해 주세요'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${connected ? bpm : 0}',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900, height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Text('bpm', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '업데이트: ${_fmtAgo(lastUpdate)}',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // 60초 스파크라인
          SizedBox(
            height: 80,
            width: double.infinity,
            child: _Sparkline(history: history),
          ),
          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('새로고침'),
          ),
        ],
      ),
    );
  }
}

/* ---------- 스파크라인(패키지 없이 CustomPainter) ---------- */

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.history});
  final List<_HrPoint> history;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparkPainter(history: history, cs: Theme.of(context).colorScheme),
      willChange: true,
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.history, required this.cs});
  final List<_HrPoint> history;
  final ColorScheme cs;

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(seconds: 60));

    // 시야 내 데이터
    final pts = history.where((p) => p.t.isAfter(cutoff)).toList();
    if (pts.length < 2) {
      // 그리드만
      _drawGrid(canvas, size);
      return;
    }

    final minBpm = (pts.map((e) => e.bpm).reduce((a, b) => a < b ? a : b) - 5).clamp(40, 120);
    final maxBpm = (pts.map((e) => e.bpm).reduce((a, b) => a > b ? a : b) + 5).clamp(50, 200);
    final span = (maxBpm - minBpm).toDouble();

    _drawGrid(canvas, size);

    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final dt = now.difference(p.t).inMilliseconds / 1000.0; // sec
      final x = size.width * (1 - (dt / 60.0)); // 오른->왼 이동
      final y = size.height * (1 - ((p.bpm - minBpm) / span));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = cs.primary;
    canvas.drawPath(path, paint);

    // 마지막 점
    final last = pts.last;
    final dt = now.difference(last.t).inMilliseconds / 1000.0;
    final x = size.width * (1 - (dt / 60.0));
    final y = size.height * (1 - ((last.bpm - minBpm) / span));
    canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = cs.primary);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = cs.onSurface.withOpacity(.06);

    // 15s 간격 세로선 5개
    for (int i = 1; i <= 3; i++) {
      final x = size.width * (i / 4);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    // 두 줄
    canvas.drawLine(Offset(0, size.height * .33), Offset(size.width, size.height * .33), grid);
    canvas.drawLine(Offset(0, size.height * .66), Offset(size.width, size.height * .66), grid);
    // 외곽
    canvas.drawRect(Offset.zero & size, grid);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) {
    return oldDelegate.history != history;
  }
}

class _HrPoint {
  _HrPoint(this.t, this.bpm);
  final DateTime t;
  final int bpm;
}

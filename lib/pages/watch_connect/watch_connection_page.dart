import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_bottom_nav.dart';

class WatchConnectPage extends StatefulWidget {
  const WatchConnectPage({super.key});

  @override
  State<WatchConnectPage> createState() => _WatchConnectPageState();
}

class _WatchConnectPageState extends State<WatchConnectPage> {
  static const platform = MethodChannel("com.example.dive_app/heart_rate");

  int _bpm = 0;
  DateTime? _lastUpdate;
  final List<_HrPoint> _history = [];
  Timer? _uiTicker;

  @override
  void initState() {
    super.initState();

    // Kotlin → Flutter로 전달된 심박수 수신
    platform.setMethodCallHandler((call) async {
      if (call.method == "onHeartRate") {
        final bpm = call.arguments as int;
        _pushHeart(bpm);
      }
    });

    // 500ms마다 UI 갱신 (표시 부드럽게)
    _uiTicker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    super.dispose();
  }

  void _pushHeart(int bpm) {
    final now = DateTime.now();
    setState(() {
      _bpm = bpm;
      _lastUpdate = now;
      _history.add(_HrPoint(now, bpm));
      // 최근 60초만 유지 (표시에는 사용 안 하지만 데이터 정리용으로 유지)
      _history.removeWhere(
            (p) => p.t.isBefore(now.subtract(const Duration(seconds: 60))),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _Header(title: "심박수", subtitle: "워치 연결됨"),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: _HeartPanel(
                  bpm: _bpm,
                  connected: true,
                  loading: false,
                  lastUpdate: _lastUpdate,
                  onRefresh: null,
                  history: _history, // 호출부 호환용(미사용)
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
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
    required this.history, // 호출부 호환용(미사용)
  });

  final int bpm;
  final bool connected;
  final bool loading;
  final DateTime? lastUpdate;
  final VoidCallback? onRefresh;
  final List<_HrPoint> history; // 미사용

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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
          // 아이콘
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withOpacity(.12),
            ),
            child: const Icon(Icons.favorite, size: 36),
          ),
          const SizedBox(height: 14),

          // 상태 텍스트
          Text(
            connected ? '현재 심박수' : (loading ? '연결 중…' : '워치를 연결해 주세요'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),

          // 심박수 숫자만 강조
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${connected ? bpm : 0}',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(width: 6),
              Text('bpm', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),

          // 업데이트 시각
          Text(
            '업데이트: ${_fmtAgo(lastUpdate)}',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),

          // 그래프 제거(아래 여백만 살짝)
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/* ---------- 데이터 모델 ---------- */

class _HrPoint {
  _HrPoint(this.t, this.bpm);
  final DateTime t;
  final int bpm;
}

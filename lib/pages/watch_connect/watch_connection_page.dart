// lib/pages/watch_connect/watch_connect_page.dart
import 'package:flutter/material.dart';
import '../../app_bottom_nav.dart';
import '../../ble/ble_manager.dart';
import 'watch_scan_page.dart'; // ← 새 스캔 페이지로 이동용

class WatchConnectPage extends StatefulWidget {
  const WatchConnectPage({super.key});

  @override
  State<WatchConnectPage> createState() => _WatchConnectPageState();
}

class _WatchConnectPageState extends State<WatchConnectPage> {
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    // 자동 스캔을 원하면 주석 해제
    // BleManager.I.scanAndConnect(containsName: "Watch").catchError((_) {});
  }

  Future<void> _connect() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      // 권한/스위치 사전 준비
      final ready = await BleManager.I.prepare();
      if (!ready) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('블루투스 권한/설정을 확인해 주세요.')),
        );
        return;
      }
      // 바로 자동 연결 시도(이름에 "Watch" 포함)
      await BleManager.I.scanAndConnect(containsName: "Watch");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('연결 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _openDrawerSafe(BuildContext ctx) {
    // Builder 컨텍스트 또는 maybeOf로 안전하게 열기
    final s = Scaffold.maybeOf(ctx);
    s?.openDrawer();
  }

  void _openScanPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WatchScanPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: BleManager.I.isConnected,
      builder: (context, connected, _) {
        return connected ? _buildConnected(context) : _buildDisconnected(context);
      },
    );
  }

  Scaffold _buildConnected(BuildContext context) {
    return Scaffold(
      drawer: _SideMenu(onDisconnect: () async {
        await BleManager.I.disconnect();
        if (mounted) Navigator.pop(context);
      }),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ValueListenableBuilder<String?>(
                valueListenable: BleManager.I.deviceName,
                builder: (context, name, _) => _Header(
                  title: name ?? "BLE Watch",
                  onSearch: _openScanPage, // ← 스캔 화면으로
                  onOpenDrawer: () => _openDrawerSafe(context),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: ValueListenableBuilder<int?>(
                valueListenable: BleManager.I.heartRate,
                builder: (context, hr, _) => _HealthSection(
                  heartRate: hr ?? 0,
                  steps: 0, // 대부분 벤더 SDK 필요
                  calories: 0,
                  sleep: const Duration(),
                  lastSync: DateTime.now(),
                  onRefresh: () async {
                    await BleManager.I.refresh();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('데이터가 새로고침되었습니다.')),
                    );
                  },
                  onOpenSettings: () => _openDrawerSafe(context),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  Scaffold _buildDisconnected(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      drawer: _SideMenu(onDisconnect: () async {
        await BleManager.I.disconnect();
        if (mounted) Navigator.pop(context);
      }),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                title: "BLE Watch",
                onSearch: _openScanPage, // ← 스캔 화면으로
                onOpenDrawer: () => _openDrawerSafe(context),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _ConnectionCard(
                  connected: false,
                  connecting: _connecting,
                  onTapConnect: _connect,
                  onTapManage: _openScanPage, // ← 관리 대신 스캔으로 이동
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "워치를 연결해 주세요",
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "건강 데이터를 보려면 워치 연결이 필요해요. 연결 후 자동으로 건강 화면이 열립니다.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(.75),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            icon: _connecting
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : const Icon(Icons.link),
                            label: Text(_connecting ? "연결 중..." : "자동 연결"),
                            onPressed: _connecting ? null : _connect,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openScanPage,
                            icon: const Icon(Icons.search),
                            label: const Text("주변 기기 보기"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }
}

/* ==================== 건강 섹션 위젯 ==================== */

class _HealthSection extends StatelessWidget {
  const _HealthSection({
    required this.heartRate,
    required this.steps,
    required this.calories,
    required this.sleep,
    required this.lastSync,
    required this.onRefresh,
    required this.onOpenSettings,
  });

  final int heartRate;
  final int steps;
  final int calories;
  final Duration sleep;
  final DateTime lastSync;
  final VoidCallback onRefresh;
  final VoidCallback onOpenSettings;

  String _fmtSleep(Duration d) =>
      "${d.inHours}시간 ${(d.inMinutes % 60).toString().padLeft(2, '0')}분";

  String _fmtLastSync(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return "방금 전 동기화";
    if (diff.inMinutes < 60) return "${diff.inMinutes}분 전 동기화";
    return "${diff.inHours}시간 전 동기화";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 심박 박스
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withOpacity(.2)),
              boxShadow: [
                BoxShadow(
                  blurRadius: 22,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                  color: Colors.black.withOpacity(.05),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withOpacity(.12),
                  ),
                  child: const Icon(Icons.favorite, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("현재 심박수", style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "$heartRate",
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text("bpm", style: theme.textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _fmtLastSync(lastSync),
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text("새로고침"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 지표 카드 그리드
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              _MetricCard(
                icon: Icons.directions_walk,
                title: "걸음 수",
                value: steps > 0 ? "$steps" : "-",
                unit: steps > 0 ? "steps" : "",
              ),
              _MetricCard(
                icon: Icons.local_fire_department,
                title: "소모 칼로리",
                value: calories > 0 ? "$calories" : "-",
                unit: calories > 0 ? "kcal" : "",
              ),
              _MetricCard(
                icon: Icons.nightlight_round,
                title: "수면",
                value: sleep.inMinutes > 0 ? _fmtSleep(sleep) : "-",
                unit: "",
              ),
              const _MetricCard(
                icon: Icons.monitor_heart,
                title: "최고/최저 심박",
                value: "— / —",
                unit: "bpm",
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 액션 행
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text("설정"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.sync),
                  label: const Text("데이터 동기화"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ==================== 공용 파츠 ==================== */

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onSearch,
    required this.onOpenDrawer,
  });

  final String title;
  final VoidCallback onSearch;
  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
      child: Row(
        children: [
          // Builder 없이도 안전하게 열기
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: onOpenDrawer,
            tooltip: "더보기",
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text("워치 · 건강 데이터", style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.search), onPressed: onSearch),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final String title;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(.2)),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            spreadRadius: -6,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(.05),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon),
          ),
          const Spacer(),
          Text(title, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(unit, style: theme.textTheme.titleMedium),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connected,
    required this.connecting,
    required this.onTapConnect,
    required this.onTapManage,
  });

  final bool connected;
  final bool connecting;
  final VoidCallback onTapConnect;
  final VoidCallback onTapManage;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface;
    final border = Theme.of(context).dividerColor.withOpacity(.2);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            spreadRadius: -4,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.05),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? Colors.green.withOpacity(.12) : Colors.orange.withOpacity(.12),
            ),
            child: Icon(
              connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              size: 28,
              color: connected ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              connected
                  ? "워치가 연결되어 있습니다.\n바로 기능을 시작할 수 있어요."
                  : "워치가 연결되어 있지 않습니다.\n연결을 설정해 주세요.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          if (connected)
            TextButton(onPressed: onTapManage, child: const Text("관리"))
          else
            FilledButton.icon(
              onPressed: connecting ? null : onTapConnect,
              icon: connecting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.link),
              label: Text(connecting ? "연결 중..." : "연결"),
            ),
        ],
      ),
    );
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.onDisconnect});
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: BleManager.I.deviceName,
              builder: (context, name, _) => ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text("내 워치"),
                subtitle: Text(name ?? "BLE Device"),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text("연결 관리"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("설정"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text("도움말"),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text("연결 해제"),
              onTap: onDisconnect,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../app_bottom_nav.dart';
// 필요하면 라우트 상수 쓰도록 경로 맞춰 임포트

class WatchConnectPage extends StatefulWidget {
  const WatchConnectPage({super.key});

  @override
  State<WatchConnectPage> createState() => _WatchConnectPageState();
}

class _WatchConnectPageState extends State<WatchConnectPage> {
  bool connected = true; // TODO: 실제 연결 상태와 바인딩
  String watchName = "Galaxy Watch4 (0QBB)";

  // 가짜 데이터 (실데이터 연결 시 setState로 갱신)
  int heartRate = 76;
  int steps = 4820;
  int calories = 357;
  Duration sleep = const Duration(hours: 6, minutes: 40);
  DateTime lastSync = DateTime.now().subtract(const Duration(minutes: 3));

  @override
  Widget build(BuildContext context) {
    if (connected) {
      // ✅ 연결됨: 건강 UI 바로 렌더
      return Scaffold(
        drawer: _SideMenu(onDisconnect: () {
          setState(() => connected = false);
          Navigator.pop(context);
        }),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  title: watchName,
                  onSearch: () {}, // 필요 시 검색 연결
                ),
              ),
              SliverToBoxAdapter(
                child: _HealthSection(
                  heartRate: heartRate,
                  steps: steps,
                  calories: calories,
                  sleep: sleep,
                  lastSync: lastSync,
                  onRefresh: _refreshFake, // TODO: 진짜 동기화 함수 연결
                  onOpenSettings: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      );
    }

    // ❌ 미연결: 연결 안내만 표시
    final theme = Theme.of(context);
    return Scaffold(
      drawer: _SideMenu(onDisconnect: () {
        setState(() => connected = false);
        Navigator.pop(context);
      }),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(title: watchName, onSearch: () {}),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _ConnectionCard(
                  connected: false,
                  onTapConnect: () => setState(() => connected = true),
                  onTapManage: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("워치를 연결해 주세요",
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      "건강 데이터를 보려면 워치 연결이 필요해요. 연결 후 자동으로 건강 화면이 열립니다.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(.75),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.link),
                        label: const Text("연결하러 가기"),
                        onPressed: () => setState(() => connected = true),
                      ),
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

  void _refreshFake() {
    // TODO: 여기서 실제 동기화/데이터 요청 수행
    setState(() {
      heartRate = (60 + (heartRate + 3) % 40);
      steps += 120;
      calories += 12;
      lastSync = DateTime.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('데이터가 새로고침되었습니다.')));
  }
}

/* -------------------- 건강 섹션 위젯 -------------------- */

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
                          Text("$heartRate",
                              style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, height: 1.0)),
                          const SizedBox(width: 6),
                          Text("bpm", style: theme.textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(_fmtLastSync(lastSync),
                          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
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
                value: "$steps",
                unit: "steps",
              ),
              _MetricCard(
                icon: Icons.local_fire_department,
                title: "소모 칼로리",
                value: "$calories",
                unit: "kcal",
              ),
              _MetricCard(
                icon: Icons.nightlight_round,
                title: "수면",
                value: _fmtSleep(sleep),
                unit: "",
              ),
              _MetricCard(
                icon: Icons.monitor_heart,
                title: "최고/최저 심박",
                value: "112 / 58",
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

/* -------------------- 공용 파츠 (기존 유지) -------------------- */

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onSearch});
  final String title;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
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
              Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.0)),
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
    required this.onTapConnect,
    required this.onTapManage,
  });

  final bool connected;
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
          BoxShadow(blurRadius: 22, spreadRadius: -4, offset: const Offset(0, 8), color: Colors.black.withOpacity(.05)),
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
            child: Icon(connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                size: 28, color: connected ? Colors.green : Colors.orange),
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
            FilledButton(onPressed: onTapConnect, child: const Text("연결")),
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
            const ListTile(
              leading: Icon(Icons.account_circle_outlined),
              title: Text("내 워치"),
              subtitle: Text("Galaxy Watch4"),
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

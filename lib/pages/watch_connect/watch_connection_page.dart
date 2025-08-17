import 'package:flutter/material.dart';
import '../../app_bottom_nav.dart';
import '../../routes.dart';

class WatchConnectPage extends StatefulWidget {
  const WatchConnectPage({super.key});

  @override
  State<WatchConnectPage> createState() => _WatchConnectPageState();
}

class _WatchConnectPageState extends State<WatchConnectPage> {
  bool connected = true;
  String watchName = "Galaxy Watch4 (0QBB)";

  @override
  Widget build(BuildContext context) {
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
              child: _Header(
                title: watchName,
                onSearch: () {
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _ConnectionCard(
                  connected: connected,
                  onTapConnect: () => setState(() => connected = true),
                  onTapManage: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  "시작하기",
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: [
                  _FeatureTile(
                    label: "날씨",
                    icon: Icons.wb_sunny,
                    onTap: () => _go(context, '/weather'),
                  ),
                  _FeatureTile(
                    label: "바다 날씨",
                    icon: Icons.waves,
                    onTap: () => _go(context, '/seaWeather'),
                  ),
                  _FeatureTile(
                    label: "물때",
                    icon: Icons.av_timer,
                    onTap: () => _go(context, '/tide'),
                  ),
                  _FeatureTile(
                    label: "낚시 포인트",
                    icon: Icons.place,
                    onTap: () => _go(context, '/fishing'),
                  ),
                  _FeatureTile(
                    label: "건강",
                    icon: Icons.favorite,
                    onTap: () => _go(context, '/health'),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("워치 설정", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    _SettingsRow(
                      icon: Icons.watch,
                      title: "워치 정보",
                      subtitle: connected ? "$watchName · 연결됨" : "연결 필요",
                      onTap: () => Scaffold.of(context).openDrawer(),
                    ),
                    const SizedBox(height: 8),
                    _SettingsRow(
                      icon: Icons.notifications_active,
                      title: "알림 동기화",
                      subtitle: connected ? "켜짐" : "꺼짐",
                      onTap: () {
                        // TODO: 알림 동기화 설정 이동
                      },
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

  void _go(BuildContext context, String key) {
    switch (key) {
      case '/weather':
        Navigator.pushNamed(context, Routes.home);
        break;

      case '/seaWeather':
        if (_canPopTo(context, Routes.seaWeather)) {
          Navigator.pushNamed(context, Routes.seaWeather);
        } else {
          Navigator.pushNamed(context, '/seaWeather');
        }
        break;

      case '/tide':
        if (_canPopTo(context, Routes.tide)) {
          Navigator.pushNamed(context, Routes.tide);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('물때 페이지 라우트를 먼저 등록해 주세요.')),
          );
        }
        break;

      case '/fishing':
        Navigator.pushNamed(context, Routes.fishingPointMain);
        break;

      case '/health':
        if (_canPopTo(context, Routes.health)) {
          Navigator.pushNamed(context, Routes.health);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('건강 페이지 라우트를 먼저 등록해 주세요.')),
          );
        }
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("'$key' 라우트가 아직 없어요.")),
        );
    }
  }

  bool _canPopTo(BuildContext context, String? routeName) {
    if (routeName == null || routeName.isEmpty) return false;
    return true;
  }
}

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
                Text("워치와 연결 및 기능 시작", style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.search), onPressed: onSearch),
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
            FilledButton(onPressed: onTapConnect, child: const Text("연결")),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withOpacity(.4)),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              spreadRadius: -6,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(.05),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Icon(icon, size: 32),
              const SizedBox(height: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                "시작하기",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
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

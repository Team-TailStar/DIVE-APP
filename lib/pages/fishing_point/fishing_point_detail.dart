// pages/fishing_point/fishing_point_detail.dart
import 'package:flutter/material.dart';
import 'fishing_point_main.dart'; // for FishingPoint

class FishingPointDetailPage extends StatefulWidget {
  final FishingPoint point;

  const FishingPointDetailPage({super.key, required this.point});

  /// Helper to build from RouteSettings.arguments
  static Widget from(Object? args) {
    if (args is FishingPoint) return FishingPointDetailPage(point: args);
    return const _ArgErrorPage();
  }

  @override
  State<FishingPointDetailPage> createState() => _FishingPointDetailPageState();
}

class _FishingPointDetailPageState extends State<FishingPointDetailPage> {
  /// 0:봄, 1:여름, 2:가을, 3:겨울
  int _seasonIndex = 0;

  late final Map<int, _SeasonInfo> _seasonData = {
    0: const _SeasonInfo(
      waterTemp: '수온\n표층: 16.8°C  저층: 13.9°C',
      species: '감성돔, 참돔, 농어, 볼락',
    ),
    1: const _SeasonInfo(
      waterTemp: '수온\n표층: 21.3°C  저층: 18.7°C',
      species: '농어, 전갱이, 고등어',
    ),
    2: const _SeasonInfo(
      waterTemp: '수온\n표층: 18.1°C  저층: 15.3°C',
      species: '감성돔, 우럭, 전갱이',
    ),
    3: const _SeasonInfo(
      waterTemp: '수온\n표층: 10.4°C  저층: 9.1°C',
      species: '볼락, 우럭',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final p = widget.point;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _MapHeader(onBack: () => Navigator.pop(context))),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  // 기본 정보 카드
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MiniBadge(icon: Icons.label_rounded, label: '영종도·용유도'),
                            _MiniBadge(icon: Icons.water_drop_outlined, label: '수심'),
                            _MiniBadge(icon: Icons.terrain_rounded, label: '바닥지형 펄'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.waves_outlined,
                          iconColor: const Color(0xFF2A79FF),
                          text: p.depthRange,
                        ),
                        const SizedBox(height: 4),
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          iconColor: Colors.redAccent,
                          text: p.location,
                        ),
                        const SizedBox(height: 4),
                        _InfoRow(
                          icon: Icons.arrow_right_alt_rounded,
                          iconColor: Colors.black54,
                          text: p.species.join(', '),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 계절별 어종 정보
                  _SectionCard(
                    title: '계절별 어종 정보',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SeasonChips(
                          index: _seasonIndex,
                          onChanged: (i) => setState(() => _seasonIndex = i),
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.thermostat,
                          iconColor: Colors.orange.shade700,
                          text: _seasonData[_seasonIndex]!.waterTemp,
                        ),
                        const SizedBox(height: 4),
                        _InfoRow(
                          icon: Icons.sailing_outlined,
                          iconColor: Colors.blueGrey,
                          text: _seasonData[_seasonIndex]!.species,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 주의사항
                  _SectionCard(
                    title: '주의사항',
                    child: _WarningBlock(
                      text:
                      '영종도 남쪽에 간출암이 존재하고, 연화도와 우도를 연결하는 전차선(해상 케이블)이 있다. 또한 북쪽 해상에 양식장이 있으므로 운항하는 선박은 주의해야 한다.',
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 상세 정보
                  _SectionCard(
                    title: '상세 정보',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _BulletBlock(
                          icon: Icons.waves,
                          title: '조류 정보',
                          body:
                          '백암도 남서쪽에서의 정조류는 외화도부터 북동방향으로 2.3kn로 흐르고, 낙조류는 남서방향으로 2.5kn로 흐른다. 외화도의 동쪽 사이 및 북서에 소류대가 형성되어 따라가며 낚시가 잘 되는 포인트가 있다.',
                        ),
                        SizedBox(height: 10),
                        _BulletBlock(
                          icon: Icons.cloud_outlined,
                          title: '기상 정보',
                          body:
                          '기온의 연교차가 비교적 큰 대륙성기후의 특징이 나타난다. 봄, 가을철에는 북서풍이 불며 강풍이 잦고 한여름에는 약한 남서풍, 겨울 후반에는 동해안에서의 영향으로 2~3°C 정도 낮은 편이다.',
                        ),
                        SizedBox(height: 10),
                        _BulletBlock(
                          icon: Icons.place_outlined,
                          title: '포인트 소개',
                          body:
                          '이 부근의 주요 어종은 넙치, 노래미, 농어, 참돔, 우럭 등이다. 루어낚시는 썰물 초반과 끝물, 지그헤드 훅 또는 메탈지그가 효과적이다. 인조방파제, 해변부는 조경이 고정적이며, 잠재적인 조류의 변화에 따라 포인트가 형성된다. 주차 및 간단한 준비가 용이한 초보자 친화형 포인트로, 초여름부터 낚시활동이 편리하다.',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------- small widgets ----------

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map placeholder (replace with Kakao/Naver/Google Map if you have one)
        Container(
          height: 220,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: const Color(0xFFE5F1FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF8DBDFF), width: 2),
            image: const DecorationImage(
              image: AssetImage('assets/map_placeholder.png'), // optional
              fit: BoxFit.cover,
              onError: null,
            ),
          ),
          child: const Center(
            child: Icon(Icons.location_pin, size: 36, color: Colors.blueAccent),
          ),
        ),
        Positioned(
          top: 20,
          left: 24,
          child: Material(
            color: Colors.white,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(24),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back_ios_new, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({this.title, required this.child});
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE6E9EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13.5, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF4067E6)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4067E6),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonChips extends StatelessWidget {
  const _SeasonChips({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['봄', '여름', '가을', '겨울'];
    return Wrap(
      spacing: 8,
      children: List.generate(labels.length, (i) {
        final selected = index == i;
        return ChoiceChip(
          label: Text(labels[i]),
          selected: selected,
          onSelected: (_) => onChanged(i),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFF0B6AAE) : Colors.black87,
          ),
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFFEAF4FF),
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? const Color(0xFFB6DAFF) : const Color(0xFFE4E6EB),
            ),
          ),
        );
      }),
    );
  }
}

class _WarningBlock extends StatelessWidget {
  const _WarningBlock({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE1A6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF8B00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: Color(0xFF6A4A00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletBlock extends StatelessWidget {
  const _BulletBlock({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13.5)),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(fontSize: 13.5, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeasonInfo {
  final String waterTemp;
  final String species;
  const _SeasonInfo({required this.waterTemp, required this.species});
}

class _ArgErrorPage extends StatelessWidget {
  const _ArgErrorPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('No FishingPoint passed to detail page.')),
    );
  }
}
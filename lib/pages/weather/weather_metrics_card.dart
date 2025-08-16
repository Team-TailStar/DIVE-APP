import 'package:flutter/material.dart';
import 'weather_models.dart';

class WeatherMetricsCard extends StatelessWidget {
  final NowItem current;
  const WeatherMetricsCard({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _mini(Icons.air, '풍속', '${current.windSpd.toStringAsFixed(1)} m/s'),
          _divider(),
          _mini(Icons.opacity, '습도', '${current.humidity.toStringAsFixed(0)} %'),
          _divider(),
          _mini(Icons.waves, '파고', '${current.waveHt.toStringAsFixed(2)} m'),
          _divider(),
          _mini(Icons.umbrella, '강수', '${current.rainMm.toStringAsFixed(1)} mm'),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 40, color: Colors.white.withOpacity(0.35));

  Widget _mini(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

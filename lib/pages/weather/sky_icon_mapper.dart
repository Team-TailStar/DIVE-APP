import 'package:flutter/material.dart';

IconData skyCodeToIcon(String code) {
  switch (code) {
    case '1': // 맑음
      return Icons.wb_sunny_rounded;
    case '2': // 구름조금
      return Icons.cloud_queue_rounded;
    case '3': // 구름많음(가정)
      return Icons.cloud_rounded;
    case '4': // 비(가정)
      return Icons.umbrella_rounded;
    default:
      return Icons.wb_cloudy_outlined;
  }
}

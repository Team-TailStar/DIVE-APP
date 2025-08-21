// lib/models/fishing_point.dart
class FishingPoint {
  final String id;
  final String name;
  final String location;   // 예: '인천광역시 옹진군'
  final double distanceKm; // 예: 11.7
  final String depthRange; // 예: '2.4~2.9m'
  final List<String> species;
  final String imageUrl;
  final double? lat;
  final double? lng;

  const FishingPoint({
    required this.id,
    required this.name,
    required this.location,
    required this.distanceKm,
    required this.depthRange,
    required this.species,
    required this.imageUrl,
    this.lat,
    this.lng,
  });
}

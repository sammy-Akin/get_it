class ShopModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String category;
  final String address;
  final double rating;
  final int totalReviews;
  final bool isOpen;
  final String openingHours;
  final String closingHours;
  final double latitude;
  final double longitude;

  ShopModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.address,
    required this.rating,
    required this.totalReviews,
    required this.isOpen,
    required this.openingHours,
    required this.closingHours,
    required this.latitude,
    required this.longitude,
  });

  factory ShopModel.fromMap(Map<String, dynamic> map, String id) {
    return ShopModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      category: map['category'] ?? '',
      address: map['address'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      totalReviews: map['totalReviews'] ?? 0,
      isOpen: map['isOpen'] ?? false,
      openingHours: map['openingHours'] ?? '8:00 AM',
      closingHours: map['closingHours'] ?? '9:00 PM',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'category': category,
      'address': address,
      'rating': rating,
      'totalReviews': totalReviews,
      'isOpen': isOpen,
      'openingHours': openingHours,
      'closingHours': closingHours,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

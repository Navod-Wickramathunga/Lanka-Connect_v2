const Map<String, String> _serviceImageByCategory = {
  'cleaning':
      'https://images.pexels.com/photos/6197116/pexels-photo-6197116.jpeg?cs=srgb&dl=pexels-tima-miroshnichenko-6197116.jpg&fm=jpg',
  'plumbing':
      'https://images.pexels.com/photos/7859953/pexels-photo-7859953.jpeg?cs=srgb&dl=pexels-heiko-ruth-53441229-7859953.jpg&fm=jpg',
  'electrical':
      'https://images.pexels.com/photos/10871585/pexels-photo-10871585.jpeg?cs=srgb&dl=pexels-annaszakaria-10871585.jpg&fm=jpg',
  'carpentry':
      'https://images.pexels.com/photos/7483049/pexels-photo-7483049.jpeg?cs=srgb&dl=pexels-cottonbro-7483049.jpg&fm=jpg',
  'painting':
      'https://images.pexels.com/photos/994164/pexels-photo-994164.jpeg?cs=srgb&dl=pexels-muffinsaurs-994164.jpg&fm=jpg',
  'gardening':
      'https://images.pexels.com/photos/24595769/pexels-photo-24595769.jpeg?cs=srgb&dl=pexels-stitch-24595769.jpg&fm=jpg',
  'moving':
      'https://images.pexels.com/photos/7464723/pexels-photo-7464723.jpeg?cs=srgb&dl=pexels-rdne-7464723.jpg&fm=jpg',
  'beauty':
      'https://images.pexels.com/photos/11041338/pexels-photo-11041338.jpeg?cs=srgb&dl=pexels-ishola-s-oladimeji-172083636-11041338.jpg&fm=jpg',
  'tutoring':
      'https://images.pexels.com/photos/8617736/pexels-photo-8617736.jpeg?cs=srgb&dl=pexels-yankrukov-8617736.jpg&fm=jpg',
};

List<String> resolveServiceImageUrls({required Map<String, dynamic> data}) {
  final rawImages = data['imageUrls'];
  final images = rawImages is List
      ? rawImages
            .map((e) => e.toString().trim())
            .where((url) => url.isNotEmpty)
            .toList()
      : <String>[];
  if (images.isNotEmpty) {
    return images;
  }
  return defaultServiceImageUrls(
    category: (data['category'] ?? '').toString(),
    title: (data['title'] ?? '').toString(),
  );
}

String? resolvePrimaryServiceImageUrl({required Map<String, dynamic> data}) {
  final images = resolveServiceImageUrls(data: data);
  if (images.isEmpty) {
    return null;
  }
  return images.first;
}

List<String> defaultServiceImageUrls({
  required String category,
  String title = '',
}) {
  final normalizedCategory = category.trim().toLowerCase();
  final imageUrl = _serviceImageByCategory[normalizedCategory];
  if (imageUrl == null || imageUrl.isEmpty) {
    return const <String>[];
  }
  return <String>[imageUrl];
}

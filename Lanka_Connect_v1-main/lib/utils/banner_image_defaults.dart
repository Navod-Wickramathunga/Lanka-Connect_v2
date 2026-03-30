const String _cleaningBannerImage =
    'https://images.pexels.com/photos/14675103/pexels-photo-14675103.jpeg';
const String _plumbingBannerImage =
    'https://images.pexels.com/photos/7859953/pexels-photo-7859953.jpeg';
const String _providerBannerImage =
    'https://images.pexels.com/photos/13821194/pexels-photo-13821194.jpeg';
const String _movingBannerImage =
    'https://images.pexels.com/photos/7464723/pexels-photo-7464723.jpeg';
const String _beautyBannerImage =
    'https://images.pexels.com/photos/11041338/pexels-photo-11041338.jpeg';
const String _tutoringBannerImage =
    'https://images.pexels.com/photos/8617736/pexels-photo-8617736.jpeg';

String? defaultBannerImageUrl({
  required String title,
  required String subtitle,
  required String ctaText,
}) {
  final haystack = '${title.trim()} ${subtitle.trim()} ${ctaText.trim()}'
      .toLowerCase();

  if (haystack.contains('spring cleaning sale') ||
      haystack.contains('professional home cleaning')) {
    return _cleaningBannerImage;
  }
  if (haystack.contains('emergency plumbing')) {
    return _plumbingBannerImage;
  }
  if (haystack.contains('join as a pro')) {
    return _providerBannerImage;
  }

  if (haystack.contains('clean') || haystack.contains('sanit')) {
    return _cleaningBannerImage;
  }
  if (haystack.contains('plumb') ||
      haystack.contains('pipe') ||
      haystack.contains('leak') ||
      haystack.contains('sink')) {
    return _plumbingBannerImage;
  }
  if (haystack.contains('move') || haystack.contains('relocat')) {
    return _movingBannerImage;
  }
  if (haystack.contains('beauty') ||
      haystack.contains('makeup') ||
      haystack.contains('spa')) {
    return _beautyBannerImage;
  }
  if (haystack.contains('tutor') ||
      haystack.contains('class') ||
      haystack.contains('study') ||
      haystack.contains('learn')) {
    return _tutoringBannerImage;
  }
  if (haystack.contains('join') ||
      haystack.contains('register') ||
      haystack.contains('provider') ||
      haystack.contains('pro') ||
      haystack.contains('business')) {
    return _providerBannerImage;
  }

  return _providerBannerImage;
}

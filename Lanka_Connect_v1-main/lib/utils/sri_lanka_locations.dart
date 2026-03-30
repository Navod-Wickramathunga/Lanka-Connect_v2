class SriLankaLocations {
  static const List<String> districts = [
    'Ampara',
    'Anuradhapura',
    'Badulla',
    'Batticaloa',
    'Colombo',
    'Galle',
    'Gampaha',
    'Hambantota',
    'Jaffna',
    'Kalutara',
    'Kandy',
    'Kegalle',
    'Kilinochchi',
    'Kurunegala',
    'Mannar',
    'Matale',
    'Matara',
    'Monaragala',
    'Mullaitivu',
    'Nuwara Eliya',
    'Polonnaruwa',
    'Puttalam',
    'Ratnapura',
    'Trincomalee',
    'Vavuniya',
  ];

  static const Map<String, List<String>> _cityByDistrict = {
    'Ampara': ['Ampara', 'Kalmunai', 'Akkaraipattu', 'Sainthamaruthu'],
    'Anuradhapura': [
      'Anuradhapura',
      'Kekirawa',
      'Medawachchiya',
      'Tambuttegama',
    ],
    'Badulla': ['Badulla', 'Bandarawela', 'Ella', 'Mahiyanganaya'],
    'Batticaloa': ['Batticaloa', 'Kattankudy', 'Eravur', 'Valachchenai'],
    'Colombo': [
      'Colombo 01',
      'Colombo 03',
      'Colombo 05',
      'Colombo 07',
      'Dehiwala',
      'Nugegoda',
      'Maharagama',
      'Rajagiriya',
      'Battaramulla',
      'Kotte',
      'Mount Lavinia',
    ],
    'Galle': ['Galle', 'Hikkaduwa', 'Ambalangoda', 'Karapitiya'],
    'Gampaha': [
      'Gampaha',
      'Negombo',
      'Kadawatha',
      'Ja-Ela',
      'Wattala',
      'Kelaniya',
    ],
    'Hambantota': ['Hambantota', 'Tangalle', 'Beliatta', 'Kataragama'],
    'Jaffna': ['Jaffna', 'Chavakachcheri', 'Nallur', 'Point Pedro'],
    'Kalutara': ['Kalutara', 'Panadura', 'Horana', 'Beruwala'],
    'Kandy': ['Kandy', 'Peradeniya', 'Katugastota', 'Gampola'],
    'Kegalle': ['Kegalle', 'Mawanella', 'Warakapola', 'Rambukkana'],
    'Kilinochchi': ['Kilinochchi', 'Poonakary', 'Paranthan'],
    'Kurunegala': ['Kurunegala', 'Kuliyapitiya', 'Narammala', 'Pannala'],
    'Mannar': ['Mannar', 'Murunkan', 'Madhu', 'Pesalai'],
    'Matale': ['Matale', 'Dambulla', 'Galewela', 'Ukuwela'],
    'Matara': ['Matara', 'Weligama', 'Akuressa', 'Dikwella'],
    'Monaragala': ['Monaragala', 'Wellawaya', 'Bibile', 'Kataragama'],
    'Mullaitivu': ['Mullaitivu', 'Oddusuddan', 'Puthukudiyiruppu'],
    'Nuwara Eliya': ['Nuwara Eliya', 'Hatton', 'Talawakele', 'Ginigathhena'],
    'Polonnaruwa': ['Polonnaruwa', 'Kaduruwela', 'Hingurakgoda'],
    'Puttalam': ['Puttalam', 'Chilaw', 'Wennappuwa', 'Marawila'],
    'Ratnapura': ['Ratnapura', 'Embilipitiya', 'Balangoda', 'Pelmadulla'],
    'Trincomalee': ['Trincomalee', 'Kinniya', 'Kantale', 'Nilaveli'],
    'Vavuniya': ['Vavuniya', 'Nedunkeni', 'Cheddikulam'],
  };

  static List<String> citiesForDistrict(String district) {
    final selected = district.trim();
    if (selected.isNotEmpty && _cityByDistrict.containsKey(selected)) {
      return [..._cityByDistrict[selected]!];
    }
    return allCities;
  }

  static List<String> get allCities {
    return _cityByDistrict.values.expand((values) => values).toSet().toList()
      ..sort();
  }
}

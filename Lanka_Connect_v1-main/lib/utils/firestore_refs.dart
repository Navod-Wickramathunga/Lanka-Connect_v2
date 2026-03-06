import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreRefs {
  static final FirebaseFirestore db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> users() =>
      db.collection('users');

  static CollectionReference<Map<String, dynamic>> services() =>
      db.collection('services');

  static CollectionReference<Map<String, dynamic>> requests() =>
      db.collection('requests');

  static CollectionReference<Map<String, dynamic>> bookings() =>
      db.collection('bookings');

  static CollectionReference<Map<String, dynamic>> messages() =>
      db.collection('messages');

  static CollectionReference<Map<String, dynamic>> reviews() =>
      db.collection('reviews');

  static CollectionReference<Map<String, dynamic>> notifications() =>
      db.collection('notifications');

  static CollectionReference<Map<String, dynamic>> payments() =>
      db.collection('payments');

  static CollectionReference<Map<String, dynamic>> offers() =>
      db.collection('offers');

  static CollectionReference<Map<String, dynamic>> banners() =>
      db.collection('banners');

  static CollectionReference<Map<String, dynamic>> promotions() =>
      db.collection('promotions');

  static CollectionReference<Map<String, dynamic>> providerBankAccounts() =>
      db.collection('providerBankAccounts');

  static CollectionReference<Map<String, dynamic>> paymentReceipts() =>
      db.collection('paymentReceipts');
}

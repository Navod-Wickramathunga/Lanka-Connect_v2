import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/offer_service.dart';
import '../../utils/validators.dart';

enum _PaymentMethod { card, savedCard, bankTransfer }

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const bool _paymentsV2Enabled = bool.fromEnvironment(
    'payments_v2_enabled',
    defaultValue: true,
  );

  final _cardFormKey = GlobalKey<FormState>();
  final _bankFormKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _transferRefController = TextEditingController();
  final _transferAmountController = TextEditingController();

  bool _saving = false;
  bool _loadingOffer = true;
  bool _saveCardForFuture = false;
  DateTime? _transferPaidAt;
  String? _selectedSavedMethodId;
  String? _selectedBankAccountId;
  _PaymentMethod _selectedMethod = _PaymentMethod.card;
  Map<String, dynamic>? _offerSummary;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _transferRefController.dispose();
    _transferAmountController.dispose();
    super.dispose();
  }

  String _shortId(String id) => id.length > 6 ? id.substring(0, 6) : id;

  Future<Map<String, dynamic>?> _resolveOfferSummary(
    Map<String, dynamic> booking,
  ) async {
    try {
      final serviceId = (booking['serviceId'] ?? '').toString();
      final providerId = (booking['providerId'] ?? '').toString();
      final grossAmount = (booking['amount'] is num)
          ? (booking['amount'] as num).toDouble()
          : 0.0;
      String category = '';
      if (serviceId.isNotEmpty) {
        final serviceDoc = await FirestoreRefs.services().doc(serviceId).get();
        category = (serviceDoc.data()?['category'] ?? '').toString();
      }
      final offers = await OfferService.loadActiveOffers();
      final applied = OfferService.resolveBestOffer(
        offers: offers,
        grossAmount: grossAmount,
        serviceId: serviceId,
        providerId: providerId,
        category: category,
      );
      if (applied == null) {
        return {
          'grossAmount': grossAmount,
          'discountAmount': 0.0,
          'netAmount': grossAmount,
        };
      }
      return {
        'grossAmount': applied.grossAmount,
        'discountAmount': applied.discountAmount,
        'netAmount': applied.netAmount,
        'appliedOfferId': applied.offerId,
        'discountMeta': applied.meta,
      };
    } catch (_) {
      return null;
    }
  }

  double _resolveNetAmount(Map<String, dynamic> booking) {
    final fallback = (booking['amount'] is num)
        ? (booking['amount'] as num).toDouble()
        : 0.0;
    final net = _offerSummary?['netAmount'];
    return net is num ? net.toDouble() : fallback;
  }

  Future<void> _launchCheckout(String checkoutUrl) async {
    final uri = Uri.tryParse(checkoutUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _startCardCheckout({
    required Map<String, dynamic> booking,
    String? paymentMethodId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      FirestoreErrorHandler.showSignInRequired(context);
      return;
    }

    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : (user.email ?? '').trim();
    final phoneRaw = _phoneController.text.trim();
    final phone = Validators.normalizePhoneToE164(phoneRaw);

    setState(() => _saving = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'createPayHereCheckoutSession',
      );
      final response = await callable.call({
        'bookingId': widget.bookingId,
        'paymentMethodId': paymentMethodId,
        'saveCard': _saveCardForFuture && paymentMethodId == null,
        'payerEmail': email,
        'payerPhone': phone,
        'methodType': paymentMethodId == null ? 'card' : 'saved_card',
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      final checkoutUrl = (data['checkoutUrl'] ?? '').toString();
      if (checkoutUrl.isNotEmpty) {
        await _launchCheckout(checkoutUrl);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Checkout session created. Complete payment in gateway.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      FirestoreErrorHandler.showError(context, e.message ?? e.code);
    } catch (e) {
      if (!mounted) return;
      FirestoreErrorHandler.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitBankTransfer(Map<String, dynamic> booking) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      FirestoreErrorHandler.showSignInRequired(context);
      return;
    }
    final bankForm = _bankFormKey.currentState;
    if (bankForm == null || !bankForm.validate()) return;
    if (_selectedBankAccountId == null || _selectedBankAccountId!.isEmpty) {
      FirestoreErrorHandler.showError(context, 'Please select a bank account.');
      return;
    }

    final netAmount = _resolveNetAmount(booking);
    final paidAmount = double.tryParse(_transferAmountController.text.trim());
    if (paidAmount == null || (paidAmount - netAmount).abs() > 0.009) {
      FirestoreErrorHandler.showError(
        context,
        'Transferred amount must match payable amount.',
      );
      return;
    }
    if (_transferPaidAt == null) {
      FirestoreErrorHandler.showError(context, 'Please select transfer date.');
      return;
    }

    setState(() => _saving = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'submitBankTransfer',
      );
      await callable.call({
        'bookingId': widget.bookingId,
        'bankAccountId': _selectedBankAccountId,
        'transferReference': _transferRefController.text.trim(),
        'paidAmount': paidAmount,
        'paidAt': Timestamp.fromDate(_transferPaidAt!),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bank transfer submitted. Waiting for admin verification.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      FirestoreErrorHandler.showError(context, e.message ?? e.code);
    } catch (e) {
      if (!mounted) return;
      FirestoreErrorHandler.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildAmountCard(Map<String, dynamic> booking) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking: ${_shortId(widget.bookingId)}'),
            const SizedBox(height: 6),
            Text(
              'Gross amount: LKR ${(_offerSummary?['grossAmount'] ?? booking['amount'] ?? 0)}',
            ),
            const SizedBox(height: 6),
            Text('Discount: LKR ${(_offerSummary?['discountAmount'] ?? 0)}'),
            const SizedBox(height: 6),
            Text(
              'Payable amount: LKR ${(_offerSummary?['netAmount'] ?? booking['amount'] ?? 0)}',
            ),
            if ((_offerSummary?['appliedOfferId'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Applied offer: ${_offerSummary?['appliedOfferId']}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodPicker() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Method',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Card'),
                  selected: _selectedMethod == _PaymentMethod.card,
                  onSelected: (_) =>
                      setState(() => _selectedMethod = _PaymentMethod.card),
                ),
                ChoiceChip(
                  label: const Text('Saved Card'),
                  selected: _selectedMethod == _PaymentMethod.savedCard,
                  onSelected: (_) => setState(
                    () => _selectedMethod = _PaymentMethod.savedCard,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Bank Transfer'),
                  selected: _selectedMethod == _PaymentMethod.bankTransfer,
                  onSelected: (_) => setState(
                    () => _selectedMethod = _PaymentMethod.bankTransfer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSection(Map<String, dynamic> booking) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _cardFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter Card Details',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Card number'),
                validator: Validators.cardNumberField,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Expiry MM/YY',
                      ),
                      validator: Validators.expiryField,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'CVV'),
                      validator: Validators.cvvField,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cardHolderController,
                decoration: const InputDecoration(
                  labelText: 'Card holder name',
                ),
                validator: (v) =>
                    Validators.requiredField(v, 'Card holder name is required'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Receipt email'),
                validator: Validators.emailField,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'SMS phone'),
                validator: Validators.phoneField,
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Save card for future use'),
                value: _saveCardForFuture,
                onChanged: (value) {
                  setState(() => _saveCardForFuture = value == true);
                },
              ),
              ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final form = _cardFormKey.currentState;
                        if (form == null || !form.validate()) return;
                        await _startCardCheckout(booking: booking);
                      },
                child: Text(_saving ? 'Processing...' : 'Pay with Card'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedCardSection(Map<String, dynamic> booking, String uid) {
    final methodsStream = FirestoreRefs.users()
        .doc(uid)
        .collection('savedPaymentMethods')
        .where('status', isEqualTo: 'active')
        .orderBy('isDefault', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: methodsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data?.docs ?? const [];
            if (docs.isEmpty) {
              return const Text(
                'No saved cards found. Add one using Card method.',
              );
            }
            if (_selectedSavedMethodId == null ||
                _selectedSavedMethodId!.isEmpty) {
              _selectedSavedMethodId = docs.first.id;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Saved Cards',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: _selectedSavedMethodId ?? '',
                  onChanged: (value) => setState(() {
                    _selectedSavedMethodId = value;
                  }),
                  child: Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final brand = (data['brand'] ?? 'Card').toString();
                      final last4 = (data['last4'] ?? '****').toString();
                      final expiryMonth =
                          (data['expiryMonth'] ?? '').toString();
                      final expiryYear =
                          (data['expiryYear'] ?? '').toString();
                      return RadioListTile<String>(
                        title: Text('$brand •••• $last4'),
                        subtitle: Text('Exp: $expiryMonth/$expiryYear'),
                        value: doc.id,
                      );
                    }).toList(),
                  ),
                ),
                ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (_selectedSavedMethodId == null) return;
                          await _startCardCheckout(
                            booking: booking,
                            paymentMethodId: _selectedSavedMethodId,
                          );
                        },
                  child: Text(
                    _saving ? 'Processing...' : 'Pay with Saved Card',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBankTransferSection(Map<String, dynamic> booking) {
    final providerId = (booking['providerId'] ?? '').toString();
    final netAmount = _resolveNetAmount(booking);
    if (_transferAmountController.text.trim().isEmpty) {
      _transferAmountController.text = netAmount.toStringAsFixed(2);
    }

    final accountsStream = FirestoreRefs.providerBankAccounts()
        .where('providerId', isEqualTo: providerId)
        .where('isActive', isEqualTo: true)
        .snapshots();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _bankFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Direct Bank Transfer',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: accountsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final accounts = snapshot.data?.docs ?? const [];
                  if (accounts.isEmpty) {
                    return const Text('No active bank account from provider.');
                  }
                  if (_selectedBankAccountId == null ||
                      _selectedBankAccountId!.isEmpty) {
                    _selectedBankAccountId = accounts.first.id;
                  }
                  return RadioGroup<String>(
                    groupValue: _selectedBankAccountId ?? '',
                    onChanged: (value) => setState(() {
                      _selectedBankAccountId = value;
                    }),
                    child: Column(
                      children: accounts.map((doc) {
                        final data = doc.data();
                        final bankName =
                            (data['bankName'] ?? '').toString();
                        final accountName =
                            (data['accountName'] ?? '').toString();
                        final masked =
                            (data['accountNumberMasked'] ?? '').toString();
                        final branch =
                            (data['branch'] ?? '').toString();
                        return RadioListTile<String>(
                          value: doc.id,
                          title: Text('$bankName • $masked'),
                          subtitle: Text('$accountName | $branch'),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _transferRefController,
                decoration: const InputDecoration(
                  labelText: 'Transfer reference',
                ),
                validator: Validators.bankReferenceField,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _transferAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Transferred amount',
                ),
                validator: (v) =>
                    Validators.priceField(v, 'Amount is required'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _transferPaidAt ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 1),
                  );
                  if (picked != null) {
                    setState(() => _transferPaidAt = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _transferPaidAt == null
                      ? 'Select transfer date'
                      : DateFormat('yyyy-MM-dd').format(_transferPaidAt!),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _saving ? null : () => _submitBankTransfer(booking),
                child: Text(_saving ? 'Submitting...' : 'Submit Bank Transfer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLatestPaymentStatus(String bookingId) {
    final query = FirestoreRefs.payments()
        .where('bookingId', isEqualTo: bookingId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!.docs.first.data();
        final status = (data['status'] ?? '').toString();
        final isSuccess = status == 'success' || status == 'paid';
        final isPending =
            status == 'pending_verification' || status == 'pending_gateway';
        final color = isSuccess
            ? Colors.green
            : isPending
            ? Colors.orange
            : Colors.red;
        final message = isSuccess
            ? 'Payment completed. Receipt sent via SMS and email.'
            : isPending
            ? 'Payment submitted and awaiting completion/verification.'
            : 'Payment failed. Please retry.';
        return Card(
          color: color.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  isSuccess
                      ? Icons.check_circle
                      : isPending
                      ? Icons.pending
                      : Icons.error,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kIsWeb) {
        return const WebPageScaffold(
          title: 'Payment',
          subtitle: 'Complete your payment securely.',
          useScaffold: true,
          child: Center(child: Text('Not signed in')),
        );
      }
      return const MobilePageScaffold(
        title: 'Payment',
        subtitle: 'Complete your payment securely.',
        accentColor: MobileTokens.primary,
        useScaffold: true,
        body: Center(child: Text('Not signed in')),
      );
    }

    final body = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.bookings().doc(widget.bookingId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(FirestoreErrorHandler.toUserMessage(snapshot.error!)),
          );
        }

        final booking = snapshot.data?.data();
        if (booking == null) {
          return const Center(child: Text('Booking not found.'));
        }

        if (_loadingOffer) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final summary = await _resolveOfferSummary(booking);
            if (!mounted) return;
            setState(() {
              _offerSummary = summary;
              _loadingOffer = false;
            });
          });
        }

        final status = (booking['status'] ?? '').toString();
        final isSeeker = (booking['seekerId'] ?? '').toString() == user.uid;
        if (!isSeeker) {
          return const Center(child: Text('Only seeker can make payment.'));
        }

        if (status != 'accepted') {
          return const Center(
            child: Text('Payment is enabled only when booking is accepted.'),
          );
        }

        if (_emailController.text.trim().isEmpty) {
          _emailController.text = user.email ?? '';
        }

        if (!_paymentsV2Enabled) {
          return const Center(
            child: Text('Payments v2 feature is currently disabled.'),
          );
        }

        final sections = <Widget>[
          _buildAmountCard(booking),
          const SizedBox(height: 12),
          _buildLatestPaymentStatus(widget.bookingId),
          const SizedBox(height: 12),
          _buildMethodPicker(),
          const SizedBox(height: 12),
          if (_selectedMethod == _PaymentMethod.card)
            _buildCardSection(booking),
          if (_selectedMethod == _PaymentMethod.savedCard)
            _buildSavedCardSection(booking, user.uid),
          if (_selectedMethod == _PaymentMethod.bankTransfer)
            _buildBankTransferSection(booking),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: sections,
          ),
        );
      },
    );

    if (kIsWeb) {
      return WebPageScaffold(
        title: 'Payment',
        subtitle: 'Card, saved methods, and bank transfer payments.',
        useScaffold: true,
        child: body,
      );
    }

    return MobilePageScaffold(
      title: 'Payment',
      subtitle: 'Card, saved methods, and bank transfer payments.',
      accentColor: MobileTokens.primary,
      useScaffold: true,
      body: body,
    );
  }
}

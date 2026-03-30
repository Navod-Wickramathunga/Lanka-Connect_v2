import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/offer.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../utils/app_feedback.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/notification_service.dart';
import '../../utils/offer_service.dart';
import '../../utils/validators.dart';

enum _PaymentMethod { card, savedCard, bankTransfer }

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 16) return oldValue;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) return oldValue;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

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
  bool _saveCardForFuture = false;
  DateTime? _transferPaidAt;
  String? _selectedSavedMethodId;
  String? _selectedBankAccountId;
  _PaymentMethod _selectedMethod = _PaymentMethod.card;

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

  double _resolveNetAmount(Map<String, dynamic> booking) {
    final fallback = (booking['amount'] is num)
        ? (booking['amount'] as num).toDouble()
        : 0.0;
    final net = booking['netAmount'];
    return net is num ? net.toDouble() : fallback;
  }

  Future<AppliedOfferResult?> _loadBestOffer(
    Map<String, dynamic> booking,
  ) async {
    final serviceId = (booking['serviceId'] ?? '').toString();
    final providerId = (booking['providerId'] ?? '').toString();
    final grossAmount = (booking['amount'] is num)
        ? (booking['amount'] as num).toDouble()
        : 0.0;
    if (serviceId.isEmpty || providerId.isEmpty || grossAmount <= 0) {
      return null;
    }

    final serviceSnap = await FirestoreRefs.services().doc(serviceId).get();
    final serviceData = serviceSnap.data();
    if (serviceData == null) return null;

    final offers = await OfferService.loadActiveOffers();
    return OfferService.resolveBestOffer(
      offers: offers,
      grossAmount: grossAmount,
      serviceId: serviceId,
      providerId: providerId,
      category: (serviceData['category'] ?? '').toString(),
    );
  }

  Future<void> _applyOffer() async {
    setState(() => _saving = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'applyBestOfferToBooking',
      );
      await callable.call({'bookingId': widget.bookingId});
      if (!mounted) return;
      TigerFeedback.show(
        context,
        'Tiger applied your best discount.',
        tone: TigerFeedbackTone.success,
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

  Future<void> _clearOffer() async {
    setState(() => _saving = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'clearBookingOffer',
      );
      await callable.call({'bookingId': widget.bookingId});
      if (!mounted) return;
      TigerFeedback.show(
        context,
        'Tiger removed the discount.',
        tone: TigerFeedbackTone.info,
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

  bool _isPaymentFinalStatus(String status) =>
      status == 'paid' || status == 'success';

  bool _isPaymentPendingStatus(String status) =>
      status == 'initiated' ||
      status == 'pending_gateway' ||
      status == 'pending_verification';

  bool _canStartNewPayment(String status) =>
      !_isPaymentFinalStatus(status) && !_isPaymentPendingStatus(status);

  Future<void> _startCardCheckout({
    required Map<String, dynamic> booking,
    String? paymentMethodId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      FirestoreErrorHandler.showSignInRequired(context);
      return;
    }
    final paymentStatus = (booking['paymentStatus'] ?? '').toString();
    if (!_canStartNewPayment(paymentStatus)) {
      FirestoreErrorHandler.showError(
        context,
        _isPaymentFinalStatus(paymentStatus)
            ? 'This booking is already paid.'
            : 'A payment attempt is already in progress. Please wait.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await FirestoreRefs.bookings().doc(widget.bookingId).update({
        'paymentStatus': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
      });

      final providerId = (booking['providerId'] ?? '').toString().trim();
      if (providerId.isNotEmpty && providerId != user.uid) {
        final amount = _resolveNetAmount(booking);
        await NotificationService.createManySafe(
          recipientIds: [providerId, user.uid],
          title: 'Seeker payment confirmed',
          body:
              'The seeker has paid LKR ${amount.toStringAsFixed(2)} for booking ${_shortId(widget.bookingId)}. You can now visit and complete the job.',
          type: 'payment',
          excludeSender: true,
          data: {
            'bookingId': widget.bookingId,
            'status': 'paid',
          },
        );
        await NotificationService.notifyAdminsSafe(
          title: 'Booking payment confirmed',
          body: 'A seeker card payment was marked paid for a booking.',
          data: {
            'bookingId': widget.bookingId,
            'providerId': providerId,
            'seekerId': user.uid,
            'status': 'paid',
          },
        );
      }

      if (!mounted) return;
      TigerFeedback.show(
        context,
        'Payment completed successfully.',
        tone: TigerFeedbackTone.success,
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
    final paymentStatus = (booking['paymentStatus'] ?? '').toString();
    if (!_canStartNewPayment(paymentStatus)) {
      FirestoreErrorHandler.showError(
        context,
        _isPaymentFinalStatus(paymentStatus)
            ? 'This booking is already paid.'
            : 'A payment attempt is already in progress. Please wait.',
      );
      return;
    }
    final bankForm = _bankFormKey.currentState;
    if (bankForm == null || !bankForm.validate()) return;
    if (_selectedBankAccountId == null || _selectedBankAccountId!.isEmpty) {
      FirestoreErrorHandler.showError(context, 'Please select a bank account.');
      return;
    }

    if (!mounted) return;

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
      TigerFeedback.show(
        context,
        'Tiger sent your transfer for verification.',
        tone: TigerFeedbackTone.success,
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
    final appliedOfferMeta = booking['appliedOfferMeta'];
    final appliedOfferTitle = appliedOfferMeta is Map
        ? (appliedOfferMeta['title'] ?? '').toString()
        : '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking: ${_shortId(widget.bookingId)}'),
            const SizedBox(height: 6),
            Text('Amount: LKR ${booking['amount'] ?? 0}'),
            if ((booking['discountAmount'] is num) &&
                (booking['discountAmount'] as num) > 0) ...[
              const SizedBox(height: 6),
              Text('Discount: LKR ${booking['discountAmount']}'),
              const SizedBox(height: 6),
              Text(
                'Payable: LKR ${booking['netAmount'] ?? booking['amount'] ?? 0}',
              ),
            ],
            if ((booking['appliedOfferId'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  appliedOfferTitle.isNotEmpty
                      ? 'Applied offer: $appliedOfferTitle'
                      : 'Applied offer: ${booking['appliedOfferId']}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferSection(Map<String, dynamic> booking, bool actionsLocked) {
    final appliedOfferId = (booking['appliedOfferId'] ?? '').toString();
    final appliedOfferMeta = booking['appliedOfferMeta'];
    final appliedOfferTitle = appliedOfferMeta is Map
        ? (appliedOfferMeta['title'] ?? '').toString()
        : '';

    return FutureBuilder<AppliedOfferResult?>(
      future: _loadBestOffer(booking),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          );
        }

        final bestOffer = snapshot.data;
        final hasAppliedOffer = appliedOfferId.isNotEmpty;
        if (!hasAppliedOffer && bestOffer == null) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exclusive Offer',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  hasAppliedOffer
                      ? 'Applied at checkout: ${appliedOfferTitle.isNotEmpty ? appliedOfferTitle : appliedOfferId}'
                      : bestOffer!.meta['title'].toString(),
                ),
                const SizedBox(height: 6),
                Text(
                  hasAppliedOffer
                      ? 'Discount saved: LKR ${booking['discountAmount'] ?? 0}'
                      : 'You can save LKR ${bestOffer!.discountAmount.toStringAsFixed(0)} on this checkout.',
                ),
                if (!actionsLocked && bestOffer != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: hasAppliedOffer || _saving
                            ? null
                            : _applyOffer,
                        icon: const Icon(Icons.local_offer_outlined),
                        label: Text(
                          _saving ? 'Applying...' : 'Apply Discount',
                        ),
                      ),
                      if (hasAppliedOffer)
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _clearOffer,
                          icon: const Icon(Icons.close),
                          label: Text(_saving ? 'Removing...' : 'Remove'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
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

  Widget _buildMethodSection(Map<String, dynamic> booking, String uid) {
    switch (_selectedMethod) {
      case _PaymentMethod.card:
        return _buildCardSection(booking);
      case _PaymentMethod.savedCard:
        return _buildSavedCardSection(booking, uid);
      case _PaymentMethod.bankTransfer:
        return _buildBankTransferSection(booking);
    }
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
                inputFormatters: [_CardNumberFormatter()],
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
                      inputFormatters: [_ExpiryFormatter()],
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
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
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
            final docs = (snapshot.data?.docs ?? const []).where((doc) {
              final tokenRef = (doc.data()['tokenRef'] ?? '').toString().trim();
              return tokenRef.isNotEmpty;
            }).toList();
            if (docs.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.credit_card_off_outlined),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No usable saved cards found for this account.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _selectedMethod = _PaymentMethod.card);
                    },
                    icon: const Icon(Icons.credit_card),
                    label: const Text('Use Card Payment'),
                  ),
                ],
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
                      final expiryMonth = (data['expiryMonth'] ?? '')
                          .toString();
                      final expiryYear = (data['expiryYear'] ?? '').toString();
                      return RadioListTile<String>(
                        title: Text('$brand **** $last4'),
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
                    return const Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Provider has not added an active bank account yet.',
                          ),
                        ),
                      ],
                    );
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
                        final bankName = (data['bankName'] ?? '').toString();
                        final accountName = (data['accountName'] ?? '')
                            .toString();
                        final masked = (data['accountNumberMasked'] ?? '')
                            .toString();
                        final branch = (data['branch'] ?? '').toString();
                        return RadioListTile<String>(
                          value: doc.id,
                          title: Text('$bankName \u2022 $masked'),
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

  /// Shows a collapsible list of all past payment attempts for this booking.
  Widget _buildPaymentHistory(String bookingId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.payments()
          .where('bookingId', isEqualTo: bookingId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final docs = snapshot.data!.docs;
        return ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            'Payment History (${docs.length})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          children: docs.map((doc) {
            final d = doc.data();
            final status = (d['status'] ?? '').toString();
            final method = (d['method'] ?? '').toString();
            final amount = (d['amount'] is num)
                ? (d['amount'] as num).toDouble()
                : 0.0;
            final ts = d['createdAt'] as Timestamp?;
            final date = ts != null
                ? DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate())
                : 'N/A';
            final isOk = status == 'success' || status == 'paid';
            final isPend =
                status == 'pending_verification' || status == 'pending_gateway';
            final color = isOk
                ? Colors.green
                : isPend
                ? Colors.orange
                : Colors.red;
            return ListTile(
              dense: true,
              leading: Icon(
                isOk
                    ? Icons.check_circle_outline
                    : isPend
                    ? Icons.pending_outlined
                    : Icons.cancel_outlined,
                color: color,
                size: 20,
              ),
              title: Text(
                'Rs ${amount.toStringAsFixed(2)} \u2022 ${method.isNotEmpty ? method : 'card'}',
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(date, style: const TextStyle(fontSize: 11)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildBookingPaymentBanner(String paymentStatus) {
    if (paymentStatus.isEmpty) {
      return const SizedBox.shrink();
    }

    final isFinal = _isPaymentFinalStatus(paymentStatus);
    final isPending = _isPaymentPendingStatus(paymentStatus);
    final color = isFinal
        ? Colors.green
        : isPending
        ? Colors.orange
        : Colors.red;
    final icon = isFinal
        ? Icons.check_circle
        : isPending
        ? Icons.pending
        : Icons.error_outline;
    final message = isFinal
        ? 'This booking is already paid.'
        : isPending
        ? 'Payment is currently in progress. You can check back in a moment.'
        : 'Previous payment failed. You can try another payment method.';

    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
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

        final status = (booking['status'] ?? '').toString();
        final paymentStatus = (booking['paymentStatus'] ?? '').toString();
        final isSeeker = (booking['seekerId'] ?? '').toString() == user.uid;
        if (!isSeeker) {
          return const Center(child: Text('Only seeker can make payment.'));
        }

        if (status != 'accepted' &&
            !_isPaymentFinalStatus(paymentStatus) &&
            !_isPaymentPendingStatus(paymentStatus)) {
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

        final actionsLocked = !_canStartNewPayment(paymentStatus);
        final sections = <Widget>[
          _buildAmountCard(booking),
          const SizedBox(height: 12),
          _buildOfferSection(booking, actionsLocked),
          const SizedBox(height: 12),
          _buildBookingPaymentBanner(paymentStatus),
          if (paymentStatus.isNotEmpty) const SizedBox(height: 12),
          _buildLatestPaymentStatus(widget.bookingId),
          const SizedBox(height: 12),
          _buildPaymentHistory(widget.bookingId),
          const SizedBox(height: 12),
          if (!actionsLocked) ...[
            _buildMethodPicker(),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: KeyedSubtree(
                key: ValueKey<String>(_selectedMethod.name),
                child: _buildMethodSection(booking, user.uid),
              ),
            ),
          ],
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

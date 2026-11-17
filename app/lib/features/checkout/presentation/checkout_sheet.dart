import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../cart/data/cart_providers.dart';
import '../../cart/domain/cart_models.dart';
import '../data/checkout_api.dart';

String formatPaise(int paise) => paise % 100 == 0
    ? '₹${paise ~/ 100}'
    : '₹${(paise / 100).toStringAsFixed(2)}';

/// Razorpay checkout: creates the order on the CMS, opens its payment page,
/// then watches the order until the server has verified the payment.
Future<void> showCheckoutSheet(BuildContext context, List<CartLine> lines) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CheckoutSheet(lines: lines),
  );
}

enum _Stage { creating, ready, waiting, paid, failed }

class _CheckoutSheet extends ConsumerStatefulWidget {
  const _CheckoutSheet({required this.lines});
  final List<CartLine> lines;

  @override
  ConsumerState<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<_CheckoutSheet>
    with WidgetsBindingObserver {
  _Stage _stage = _Stage.creating;
  CheckoutOrder? _order;
  CheckoutException? _error;
  Timer? _poll;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _create();
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the payment tab: check right away instead of waiting.
    if (state == AppLifecycleState.resumed && _stage == _Stage.waiting) {
      _check();
    }
  }

  Future<void> _create() async {
    setState(() {
      _stage = _Stage.creating;
      _error = null;
    });
    try {
      final order =
          await ref.read(checkoutApiProvider).createOrder(widget.lines);
      if (!mounted) return;
      setState(() {
        _order = order;
        _stage = _Stage.ready;
      });
      // Browsers block tabs opened without a tap, so on the web the shopper
      // taps "Pay"; on phones the payment page opens straight away.
      if (!kIsWeb) await _openPayment();
    } on CheckoutException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _stage = _Stage.failed;
        });
      }
    }
  }

  Future<void> _openPayment() async {
    final url = _order?.payUrl;
    if (url == null) return;
    final opened = await launchUrl(
      Uri.parse(url),
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
      webOnlyWindowName: '_blank',
    );
    if (!mounted) return;
    if (!opened) {
      setState(() {
        _error = const CheckoutException('Couldn\'t open the payment page.');
        _stage = _Stage.failed;
      });
      return;
    }
    setState(() => _stage = _Stage.waiting);
    _poll ??= Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  Future<void> _check() async {
    final order = _order;
    if (order == null || _checking || _stage == _Stage.paid) return;
    _checking = true;
    try {
      final latest = await ref.read(checkoutApiProvider).status(order.orderId);
      if (!mounted) return;
      if (latest.isPaid) {
        _poll?.cancel();
        setState(() {
          _order = latest;
          _stage = _Stage.paid;
        });
        // Paid: empty the cart (also syncs to the server).
        final cart = ref.read(cartProvider.notifier);
        for (final line in widget.lines) {
          await cart.setQty(line.product, 0);
        }
      }
    } on CheckoutException {
      // Transient (e.g. offline for a moment): the next tick retries.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: switch (_stage) {
            _Stage.creating => const _Body(
                icon: null,
                title: 'Starting secure payment…',
                message: 'Checking prices and stock with the store.',
              ),
            _Stage.ready => _Body(
                icon: Icons.lock_outline,
                title: 'Pay ${formatPaise(_order!.amountPaise)}',
                message: 'You\'ll pay on Razorpay\'s secure page '
                    '(UPI, cards, net banking). Order ${_order!.shortId}.',
                primaryLabel: 'Pay with Razorpay',
                onPrimary: _openPayment,
              ),
            _Stage.waiting => _Body(
                icon: null,
                title: 'Waiting for payment…',
                message: 'Finish paying on the Razorpay page. This updates '
                    'by itself once the payment is confirmed.',
                primaryLabel: 'Open payment page again',
                onPrimary: _openPayment,
                secondaryLabel: 'I\'ve paid, check now',
                onSecondary: _check,
              ),
            _Stage.paid => _Body(
                icon: Icons.check_circle,
                iconColor: context.palette.accent,
                title: 'Payment successful',
                message: '${formatPaise(_order!.amountPaise)} paid for order '
                    '${_order!.shortId}.\nPayment ID: ${_order!.paymentId ?? '-'}',
                primaryLabel: 'Done',
                onPrimary: () => Navigator.of(context).pop(),
              ),
            _Stage.failed => _Body(
                icon: _error?.notConfigured == true
                    ? Icons.payments_outlined
                    : Icons.error_outline,
                iconColor: _error?.notConfigured == true
                    ? null
                    : context.palette.danger,
                title: _error?.notConfigured == true
                    ? 'Online payment isn\'t set up yet'
                    : 'Payment couldn\'t start',
                message: _error?.notConfigured == true
                    ? 'Your cart is saved. The store hasn\'t connected '
                        'Razorpay yet.'
                    : _error?.message ?? 'Something went wrong.',
                primaryLabel:
                    _error?.notConfigured == true ? 'OK' : 'Try again',
                onPrimary: _error?.notConfigured == true
                    ? () => Navigator.of(context).pop()
                    : _create,
              ),
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          child: icon == null
              ? const Center(
                  child: SizedBox.square(
                    dimension: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                )
              : Icon(icon,
                  size: 44, color: iconColor ?? context.palette.accent,),
        ),
        const SizedBox(height: Gap.md),
        Text(title, style: text.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: Gap.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (primaryLabel != null) ...[
          const SizedBox(height: Gap.lg),
          SizedBox(
            width: double.infinity,
            height: 48,
            child:
                FilledButton(onPressed: onPrimary, child: Text(primaryLabel!)),
          ),
        ],
        if (secondaryLabel != null) ...[
          const SizedBox(height: Gap.sm),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: onSecondary,
              child: Text(secondaryLabel!),
            ),
          ),
        ],
      ],
    );
  }
}

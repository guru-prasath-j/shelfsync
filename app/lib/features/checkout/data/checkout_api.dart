import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../cart/domain/cart_models.dart';

class CheckoutException implements Exception {
  const CheckoutException(this.message, {this.notConfigured = false});
  final String message;

  /// The store hasn't added Razorpay keys yet.
  final bool notConfigured;
  @override
  String toString() => message;
}

class CheckoutOrder {
  const CheckoutOrder({
    required this.orderId,
    required this.status,
    required this.amountPaise,
    this.payUrl,
    this.paymentId,
  });

  factory CheckoutOrder.fromJson(Map<String, dynamic> j) => CheckoutOrder(
        orderId: j['orderId'] as String,
        status: j['status'] as String? ?? 'created',
        amountPaise: (j['amount'] as num?)?.toInt() ?? 0,
        payUrl: j['payUrl'] as String?,
        paymentId: j['paymentId'] as String?,
      );

  final String orderId;
  final String status;
  final int amountPaise;
  final String? payUrl;
  final String? paymentId;

  bool get isPaid => status == 'paid';
  String get shortId => orderId.substring(0, 8).toUpperCase();
}

/// Talks to the CMS checkout endpoints. Its own Dio without the ETag cache,
/// so an order's status is always read fresh.
class CheckoutApi {
  CheckoutApi(String baseUrl, {HttpClientAdapter? adapter})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 8),
            // Free hosting can take a while to wake up and call Razorpay.
            receiveTimeout: const Duration(seconds: 30),
            contentType: Headers.jsonContentType,
          ),
        ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  final Dio _dio;

  Future<CheckoutOrder> _run(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      return CheckoutOrder.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? data['error'] as String? : null;
      if (msg != null) {
        throw CheckoutException(
          msg,
          notConfigured: e.response?.statusCode == 503,
        );
      }
      throw const CheckoutException(
        'Can\'t reach the store right now. Check your connection.',
      );
    }
  }

  /// The server prices the order from its own catalogue; only ids and
  /// quantities are sent.
  Future<CheckoutOrder> createOrder(Iterable<CartLine> lines) => _run(
        () => _dio.post<dynamic>(
          'checkout/orders',
          data: {
            'lines': [
              for (final l in lines)
                if (l.qty > 0) {'productId': l.product.id, 'qty': l.qty},
            ],
          },
        ),
      );

  Future<CheckoutOrder> status(String orderId) =>
      _run(() => _dio.get<dynamic>('checkout/orders/$orderId'));
}

final checkoutApiProvider =
    Provider<CheckoutApi>((ref) => CheckoutApi(AppConfig.baseUrl));

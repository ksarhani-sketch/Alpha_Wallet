import 'dart:convert';

// REMOVE: material imports
// import 'package:flutter/foundation.dart' show debugPrint;
// import 'package:flutter/material.dart' show Color, Colors, Icons;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../finance_state.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/transaction_record.dart';
import '../models/wallet.dart';

// NEW: alias import so we can qualify enums/constants safely.
import '../models/models.dart' as models;

class FinanceApiException implements Exception {
  FinanceApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'FinanceApiException($statusCode, $message)';
}

class FinanceApiClient {
  FinanceApiClient({
    http.Client? httpClient,
    String? baseUrl,
    this.tokenProvider,
  })  : _client = httpClient ?? http.Client(),
        _baseUri = _parseBaseUri(
          baseUrl ?? const String.fromEnvironment('API_BASE_URL', defaultValue: ''),
        );

  final http.Client _client;
  final Uri? _baseUri;
  final Future<String?> Function()? tokenProvider;
  String? _lastAuthToken;

  bool get isEnabled => _baseUri != null;
  bool get hasAuthProvider => tokenProvider != null;

  void close() {
    _client.close();
  }

  static Uri? _parseBaseUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final withSlash = trimmed.endsWith('/') ? trimmed : '$trimmed/';
    final uri = Uri.tryParse(withSlash);
    if (uri == null || !uri.hasScheme) {
      debugPrint('FinanceApiClient: invalid base URL "$value"');
      return null;
    }
    return uri;
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (tokenProvider != null) {
      final token = await tokenProvider!();
      final trimmedToken = token?.trim();
      if (trimmedToken != null && trimmedToken.isNotEmpty) {
        _lastAuthToken = trimmedToken;
        headers['Authorization'] = 'Bearer $trimmedToken';
      } else {
        _lastAuthToken = null;
      }
    } else {
      _lastAuthToken = null;
    }
    return headers;
  }

  String? get _authenticatedUserId {
    final token = _lastAuthToken;
    if (token == null || token.isEmpty) {
      return null;
    }
    final segments = token.split('.');
    if (segments.length < 2) {
      return null;
    }
    try {
      final normalized = base64Url.normalize(segments[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final decoded = jsonDecode(payload);
      final sub = decoded is Map<String, dynamic> ? decoded['sub'] : null;
      if (sub is String && sub.trim().isNotEmpty) {
        return sub;
      }
    } catch (_) {}
    return null;
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    if (!isEnabled) {
      throw FinanceApiException(503, 'API client is not configured');
    }
    final uri = _baseUri!
        .resolve(path.startsWith('/') ? path.substring(1) : path)
        .replace(queryParameters: query);
    final headers = await _headers();

    late http.Response response;
    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers);
        break;
      case 'POST':
        response = await _client.post(uri, headers: headers, body: body == null ? null : jsonEncode(body));
        break;
      case 'PUT':
        response = await _client.put(uri, headers: headers, body: body == null ? null : jsonEncode(body));
        break;
      case 'DELETE':
        response = await _client.delete(uri, headers: headers);
        break;
      default:
        throw ArgumentError.value(method, 'method', 'Unsupported HTTP method');
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (error) {
        debugPrint('FinanceApiClient: failed to decode response: $error');
      }
    }

    if (response.statusCode >= 400) {
      final message = decoded is Map<String, dynamic> && decoded['message'] is String
          ? decoded['message'] as String
          : 'Request failed with status ${response.statusCode}';
      throw FinanceApiException(response.statusCode, message);
    }

    return decoded;
  }

  Future<FinanceState> fetchState() async {
    if (!isEnabled) {
      return FinanceState();
    }
    final results = await Future.wait([
      _request('GET', '/accounts'),
      _request('GET', '/categories'),
      _request('GET', '/transactions'),
      _request('GET', '/budgets', query: {
        'month': DateTime.now().toIso8601String().substring(0, 7),
      }),
    ]);

    final accountsJson = (results[0] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final categoriesJson = (results[1] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final transactionsJson = (results[2] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final budgetsJson = (results[3] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

    final wallets = accountsJson.map(_mapAccount).toList();
    final categories = categoriesJson.map(_mapCategory).toList();
    final transactions = transactionsJson.map(_mapTransaction).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final budgets = budgetsJson.map(_mapBudget).toList();

    final primaryCurrency = wallets.isNotEmpty ? wallets.first.currency : 'USD';
    final fxRates = <String, double>{primaryCurrency: 1.0};
    for (final tx in transactions) {
      if (tx.currency.isNotEmpty && tx.fxRate > 0) {
        fxRates[tx.currency] = tx.fxRate;
      }
    }

    final settings = UserSettings(
      userId: _authenticatedUserId ?? 'demo-user',
      primaryCurrency: primaryCurrency,
      locale: 'en',
      syncEnabled: true,
    );

    return FinanceState(
      categories: categories,
      wallets: wallets,
      transactions: transactions,
      budgets: budgets,
      recurringTemplates: const [],
      settings: settings,
      fxRates: fxRates,
      lastSyncedAt: DateTime.now(),
      isSyncing: false,
    );
  }

  Future<void> createTransaction({
    required String accountId,
    required String categoryId,
    required String type, // "income" | "expense"
    required double amount,
    String? note,
    List<String>? tags,
  }) async {
    await _request('POST', '/transactions', body: {
      'accountId': accountId,
      'categoryId': categoryId,
      'type': type,
      'amount': amount,
      if (note != null) 'note': note,
      if (tags != null && tags.isNotEmpty) 'tags': tags,
    });
  }

  Future<void> deleteTransaction(String txnId) async {
    await _request('DELETE', '/transactions/$txnId');
  }

  /// CLEAN: data-layer takes/returns iconName + colorHex, not UI types.
  Future<Category> createCategory({
    required String name,
    required models.CategoryType type,
    required String colorHex, // e.g. "#FF9800" (6 or 8 hex)
    required String iconName, // e.g. "shopping_bag"
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'type': type == models.CategoryType.income ? 'income' : 'expense',
      'color': _normalizeHex(colorHex),
      'icon': iconName,
    };
    final response = await _request('POST', '/categories', body: body);
    if (response is Map<String, dynamic>) {
      return _mapCategory(response);
    }
    return Category(
      id: '',
      name: name,
      type: type == models.CategoryType.income ? CategoryType.income : CategoryType.expense,
      colorHex: _normalizeHex(colorHex),
      iconName: iconName,
    );
  }

  Future<void> createBudget({
    required String month,
    required String currency,
    required double limit,
    String? categoryId,
    double? alertThreshold,
    bool rollover = false,
  }) async {
    final body = <String, dynamic>{
      'month': month,
      'currency': currency.toUpperCase(),
      'limit': limit,
      if (categoryId != null) 'categoryId': categoryId,
      if (alertThreshold != null) 'alertThreshold': alertThreshold,
      'rollover': rollover,
    };
    await _request('POST', '/budgets', body: body);
  }

  Wallet _mapAccount(Map<String, dynamic> json) {
    final type = switch ((json['type'] as String? ?? 'cash').toLowerCase()) {
      'bank' => WalletType.bank,
      'card' => WalletType.card,
      'crypto' => WalletType.crypto,
      _ => WalletType.cash,
    };
    final balanceValue = json['currentBalance'] ?? json['openingBalance'] ?? 0;
    final balance = balanceValue is num ? balanceValue.toDouble() : double.tryParse(balanceValue.toString()) ?? 0.0;
    return Wallet(
      id: json['accountId'] as String? ?? '',
      name: json['name'] as String? ?? 'Wallet',
      currency: (json['currency'] as String? ?? 'USD').toUpperCase(),
      balance: balance,
      type: type,
      isArchived: json['archived'] == true,
    );
  }

  Category _mapCategory(Map<String, dynamic> json) {
    final type = (json['type'] as String? ?? 'expense').toLowerCase() == 'income'
        ? CategoryType.income
        : CategoryType.expense;

    // NOTE: Do not parse to Color, keep hex string
    final colorHex = _normalizeHex(json['color'] as String?);

    // NOTE: Keep raw icon name from backend/app
    final iconName = (json['icon'] as String? ?? 'category').trim().isEmpty
        ? 'category'
        : (json['icon'] as String).trim();

    return Category(
      id: json['categoryId'] as String? ?? '',
      name: json['name'] as String? ?? 'Category',
      type: type,
      colorHex: colorHex,
      iconName: iconName,
    );
  }

  TransactionRecord _mapTransaction(Map<String, dynamic> json) {
    final type = (json['type'] as String? ?? 'expense').toLowerCase();
    final kind = type == 'income'
        ? models.TransactionKind.income
        : models.TransactionKind.expense;

    final occurredAt = DateTime.tryParse(json['occurredAt'] as String? ?? '') ?? DateTime.now();
    final fx = json['fx_rate_to_base'];
    final fxRate = fx is num ? fx.toDouble() : double.tryParse(fx?.toString() ?? '') ?? 1.0;
    return TransactionRecord(
      id: json['txnId'] as String? ?? json['sk'] as String? ?? '',
      walletId: json['accountId'] as String? ?? '',
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: (json['currency'] as String? ?? 'USD').toUpperCase(),
      categoryId: json['categoryId'] as String? ?? '',
      kind: kind,
      timestamp: occurredAt,
      note: json['note'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(growable: false),
      fxRate: fxRate,
    );
  }

  Budget _mapBudget(Map<String, dynamic> json) {
    final periodStart = DateTime.tryParse(json['periodStart'] as String? ?? '') ?? DateTime.now();
    final periodEnd = DateTime.tryParse(json['periodEnd'] as String? ?? '') ?? periodStart;
    return Budget(
      id: json['periodCat'] as String? ?? '${json['month'] ?? ''}#${json['categoryId'] ?? 'all'}',
      currency: (json['currency'] as String? ?? 'USD').toUpperCase(),
      limit: (json['limit'] as num? ?? 0).toDouble(),
      period: BudgetPeriod.monthly,
      periodStart: periodStart,
      periodEnd: periodEnd,
      categoryId: json['categoryId'] as String?,
      alertThreshold: (json['alertThreshold'] as num? ?? 0.9).toDouble(),
      rollover: json['rollover'] == true,
    );
  }

  // ---------- helpers (pure) ----------

  String _normalizeHex(String? hex) {
    final raw = (hex ?? '').replaceAll('#', '').trim();
    if (raw.isEmpty) return '#607D8B'; // blueGrey fallback
    // If 6-digit, add opaque alpha
    final normalized = raw.length == 6 ? 'FF$raw' : raw;
    final upper = normalized.toUpperCase();
    final valid = RegExp(r'^[0-9A-F]{8}$').hasMatch(upper);
    return '#${valid ? upper.substring(2) : '607D8B'}'; // return as #RRGGBB
  }
}

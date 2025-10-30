import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' show Color, Colors, Icons;
import 'package:http/http.dart' as http;

import '../finance_state.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/transaction_record.dart';
import '../models/user_settings.dart';
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
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
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
        response = await _client.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
        break;
      case 'PUT':
        response = await _client.put(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
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
      userId: 'remote-user',
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
    required String type,
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
    final color = _parseColor(json['color'] as String?);
    return Category(
      id: json['categoryId'] as String? ?? '',
      name: json['name'] as String? ?? 'Category',
      type: type,
      color: color,
      icon: Icons.category,
    );
  }

  TransactionRecord _mapTransaction(Map<String, dynamic> json) {
    final type = (json['type'] as String? ?? 'expense').toLowerCase();
    // FIX: qualify the enum
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

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) {
      return Colors.blueGrey;
    }
    final cleaned = hex.replaceAll('#', '');
    final buffer = StringBuffer();
    if (cleaned.length == 6) {
      buffer.write('ff');
    }
    buffer.write(cleaned);
    final value = int.tryParse(buffer.toString(), radix: 16);
    if (value == null) {
      return Colors.blueGrey;
    }
    return Color(value);
  }
}

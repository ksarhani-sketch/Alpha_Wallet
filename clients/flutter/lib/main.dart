import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3000/v1');

void main() => runApp(const CodexApp());

class CodexApp extends StatelessWidget {
  const CodexApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Codex Prototype')),
        body: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _amount = TextEditingController();
  String _status = '';

  Future<void> _addExpense() async {
    final body = {
      'type': 'expense',
      'accountId': 'demo-cash',
      'categoryId': 'demo-food',
      'amount': double.tryParse(_amount.text) ?? 0,
      'currency': 'OMR',
      'note': 'Quick add'
    };
    final r = await http.post(
      Uri.parse('$apiBase/transactions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    setState(() => _status = '${r.statusCode}: ${r.body}');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick add expense'),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount (OMR)'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _addExpense, child: const Text('Save')),
          const SizedBox(height: 12),
          Text(_status),
        ],
      ),
    );
  }
}

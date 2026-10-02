import 'package:flutter/material.dart';

class SplitCostScreen extends StatefulWidget {
  const SplitCostScreen({super.key, required this.passengers});

  final int passengers;

  @override
  State<SplitCostScreen> createState() => _SplitCostScreenState();
}

class _SplitCostScreenState extends State<SplitCostScreen> {
  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();

  late int people;
  int? totalCents;

  @override
  void initState() {
    super.initState();
    people = widget.passengers.clamp(1, 15).toInt();
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  int? parseAmount(String text) {
    final cleaned = text.trim();

    // Accept whole rupees or up to two decimal places.
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cleaned)) {
      return null;
    }

    final parts = cleaned.split('.');
    final rupees = int.tryParse(parts[0]);

    if (rupees == null || rupees > 10000000) {
      return null;
    }

    final cents = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;

    final total = rupees * 100 + cents;
    return total > 0 ? total : null;
  }

  String money(int cents) {
    final rupees = cents ~/ 100;
    final remainder = (cents % 100).toString().padLeft(2, '0');

    return 'LKR $rupees.$remainder';
  }

  void calculate() {
    FocusScope.of(context).unfocus();

    if (!formKey.currentState!.validate()) {
      setState(() {
        totalCents = null;
      });
      return;
    }

    setState(() {
      totalCents = parseAmount(amountController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = totalCents;
    final baseShare = total == null ? 0 : total ~/ people;
    final extraCentPeople = total == null ? 0 : total % people;

    return Scaffold(
      appBar: AppBar(title: const Text('Split the cost')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Icon(Icons.groups, size: 64, color: Colors.teal),
                  const SizedBox(height: 20),
                  const Text(
                    'Share the journey cost',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter an agreed fare or a sample amount. '
                    'This calculator does not collect payments.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Total fare in LKR',
                      hintText: 'For example: 28000',
                      prefixIcon: Icon(
                        Icons.payments_outlined,
                        color: Colors.teal,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (parseAmount(value ?? '') == null) {
                        return 'Enter an amount greater than zero, '
                            'up to LKR 10,000,000.';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      setState(() {
                        totalCents = null;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Expanded(child: Text('People sharing')),
                          IconButton(
                            tooltip: 'Fewer people',
                            onPressed: people > 1
                                ? () {
                                    setState(() {
                                      people--;
                                      totalCents = null;
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.remove),
                          ),
                          Text(
                            '$people',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            tooltip: 'More people',
                            onPressed: people < 15
                                ? () {
                                    setState(() {
                                      people++;
                                      totalCents = null;
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: calculate,
                    child: const Text('Calculate shares'),
                  ),
                  if (total != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Total: ${money(total)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (int i = 0; i < people; i++)
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.person_outline,
                            color: Colors.teal,
                          ),
                          title: Text('Person ${i + 1}'),
                          trailing: Text(
                            money(baseShare + (i < extraCentPeople ? 1 : 0)),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    if (extraCentPeople > 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'A few shares differ by one cent '
                          'so they add up to the exact total.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

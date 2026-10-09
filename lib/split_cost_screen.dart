import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplitCostScreen extends StatefulWidget {
  const SplitCostScreen({super.key, required this.passengers});

  final int passengers;

  @override
  State<SplitCostScreen> createState() => _SplitCostScreenState();
}

class _SplitCostScreenState extends State<SplitCostScreen> {
  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);
  static const muted = Color(0xFF738097);
  static const background = Color(0xFFF5F7FB);
  static const borderColor = Color(0xFFE5EAF2);

  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();

  late int people;
  int? totalCents;
  bool copying = false;

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

    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cleaned)) {
      return null;
    }

    final parts = cleaned.split('.');
    final rupees = int.tryParse(parts[0]);

    if (rupees == null || rupees > 10000000) return null;

    final cents = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;

    final total = rupees * 100 + cents;

    // Check the full amount, including its decimal part.
    if (total <= 0 || total > 1000000000) return null;

    return total;
  }

  String money(int cents) {
    final rupees = cents ~/ 100;
    final remainder = (cents % 100).toString().padLeft(2, '0');

    final grouped = rupees.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]},',
    );

    return 'LKR $grouped.$remainder';
  }

  int shareFor(int index, int total) {
    final baseShare = total ~/ people;
    final extraCentPeople = total % people;

    return baseShare + (index < extraCentPeople ? 1 : 0);
  }

  void changePeople(int value) {
    setState(() {
      people = value;
      totalCents = null;
    });
  }

  void calculate() {
    FocusScope.of(context).unfocus();

    if (!(formKey.currentState?.validate() ?? false)) {
      setState(() => totalCents = null);
      return;
    }

    setState(() {
      totalCents = parseAmount(amountController.text);
    });
  }

  Future<void> copyCalculation() async {
    final total = totalCents;
    if (total == null || copying) return;

    final details = [
      'TripLanka — Cost split',
      '',
      'Total: ${money(total)}',
      'People sharing: $people',
      '',
      for (int i = 0; i < people; i++)
        'Person ${i + 1}: ${money(shareFor(i, total))}',
      '',
      if (total % people != 0)
        'Some shares differ by one cent to match the exact total.',
      'Calculation only. No payments have been collected.',
    ].join('\n');

    setState(() => copying = true);

    try {
      await Clipboard.setData(ClipboardData(text: details));

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Calculation copied. Paste it into your messaging app.',
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cost split'),
          content: SingleChildScrollView(child: SelectableText(details)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => copying = false);
      }
    }
  }

  Widget section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: blue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget resultCard(int total) {
    final baseShare = total ~/ people;
    final remainder = total % people;

    return section(
      title: 'Your cost split',
      icon: Icons.receipt_long_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  remainder == 0
                      ? 'Amount per person'
                      : 'Share range per person',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  remainder == 0
                      ? money(baseShare)
                      : '${money(baseShare)} – ${money(baseShare + 1)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: blue,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total ${money(total)} · $people '
                  '${people == 1 ? 'person' : 'people'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < people; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, color: blue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Person ${i + 1}',
                      style: const TextStyle(color: navy),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      money(shareFor(i, total)),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: navy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (remainder != 0) ...[
            const SizedBox(height: 12),
            const Text(
              'Some shares differ by one cent so they '
              'add up to the exact total.',
              style: TextStyle(color: muted, fontSize: 12, height: 1.5),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: copying ? null : copyCalculation,
            style: OutlinedButton.styleFrom(
              foregroundColor: blue,
              side: const BorderSide(color: borderColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.copy_outlined, size: 19),
            label: Text(copying ? 'Copying...' : 'Copy calculation'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = totalCents;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Split the cost',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
        backgroundColor: background,
        foregroundColor: navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: Form(
                    key: formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [blue, Color(0xFF1547B8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.groups_outlined,
                                color: Colors.white,
                                size: 38,
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Travel together.\nShare the cost.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Enter your agreed fare and calculate '
                                'each person’s share.',
                                style: TextStyle(
                                  color: Color(0xFFDCE8FF),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        section(
                          title: 'Journey cost',
                          icon: Icons.payments_outlined,
                          child: TextFormField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => calculate(),
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            style: const TextStyle(
                              color: navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Total fare in LKR',
                              hintText: 'For example: 28000',
                              prefixIcon: const Icon(
                                Icons.payments_outlined,
                                color: blue,
                              ),
                              filled: true,
                              fillColor: background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: borderColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: blue,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (parseAmount(value ?? '') == null) {
                                return 'Enter a positive amount up to '
                                    'LKR 10,000,000 with at most '
                                    'two decimal places.';
                              }
                              return null;
                            },
                            onChanged: (_) {
                              if (totalCents == null) return;
                              setState(() => totalCents = null);
                            },
                          ),
                        ),
                        section(
                          title: 'People sharing',
                          icon: Icons.people_outline,
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Including you',
                                  style: TextStyle(color: muted, fontSize: 13),
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: 'Fewer people',
                                onPressed: people > 1
                                    ? () => changePeople(people - 1)
                                    : null,
                                icon: const Icon(Icons.remove),
                              ),
                              SizedBox(
                                width: 36,
                                child: Text(
                                  '$people',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: navy,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: 'More people',
                                onPressed: people < 15
                                    ? () => changePeople(people + 1)
                                    : null,
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ),
                        if (total != null) resultCard(total),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Calculator only. The amount is entered '
                            'by you; TripLanka does not collect '
                            'payments or confirm the fare.',
                            style: TextStyle(
                              color: muted,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: calculate,
                      style: FilledButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text(
                        'Calculate shares',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

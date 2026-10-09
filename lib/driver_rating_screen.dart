import 'package:flutter/material.dart';

class DriverRatingDraft {
  const DriverRatingDraft({required this.stars, required this.comment});

  final int stars;
  final String comment;
}

class DriverRatingScreen extends StatefulWidget {
  const DriverRatingScreen({
    super.key,
    required this.driverName,
    required this.destination,
  });

  final String driverName;
  final String destination;

  @override
  State<DriverRatingScreen> createState() => _DriverRatingScreenState();
}

class _DriverRatingScreenState extends State<DriverRatingScreen> {
  final commentController = TextEditingController();
  int stars = 0;

  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);

  final descriptions = const [
    'Choose your rating',
    'Poor',
    'Fair',
    'Good',
    'Very good',
    'Excellent',
  ];

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  void continueWithRating() {
    if (stars == 0) return;

    FocusScope.of(context).unfocus();

    Navigator.of(context).pop<DriverRatingDraft>(
      DriverRatingDraft(stars: stars, comment: commentController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.driverName.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Rate your driver'),
        backgroundColor: const Color(0xFFF5F7FB),
        foregroundColor: navy,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 16),
                const Center(
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: Color(0xFFE8EFFF),
                    child: Icon(Icons.person_outline, size: 48, color: blue),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  name.isEmpty ? 'Your driver' : name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your trip to ${widget.destination}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF738097)),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'How was your journey?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: navy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Rate your experience with this driver.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF738097)),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          for (int index = 1; index <= 5; index++)
                            IconButton(
                              tooltip:
                                  '$index ${index == 1 ? 'star' : 'stars'}',
                              isSelected: stars >= index,
                              onPressed: () {
                                setState(() {
                                  stars = index;
                                });
                              },
                              icon: Icon(
                                stars >= index
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: stars >= index
                                    ? const Color(0xFFF4B400)
                                    : const Color(0xFFBCC5D3),
                                size: 38,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        descriptions[stars],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: commentController,
                  maxLength: 500,
                  minLines: 4,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Review (optional)',
                    hintText: 'Tell us about your journey.',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: stars == 0 ? null : continueWithRating,
                  style: FilledButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your rating will be saved after confirmation '
                  'on the booking page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF738097)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class ReportProblemScreen extends StatefulWidget {
  final String? sourceScreen;
  const ReportProblemScreen({super.key, this.sourceScreen});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  String? _selectedCategory;
  String? _selectedImagePath;

  final List<String> _categories = [
    'General Feedback',
    'Technical Bug',
    'Profile Issue',
    'Content Violation',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.sourceScreen ?? _categories.first;
  }

  /// Submits the user's feedback or report.
  /// It validates that the feedback is not empty, simulates a network call with a delay, and shows a thank-you dialog.
  void _submitFeedback() async {
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide some details about the problem.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulate network call

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thank You!'),
        content: const Text('Your report has been sent to the moderator. We will look into it shortly.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _pickImage() {
    // Simulated image picking
    setState(() {
      _selectedImagePath = "dummy_path_from_picker";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image selected successfully (Simulated)')),
    );
  }

  /// Builds the UI for the report problem screen.
  /// Provides a multi-line text field for the user to describe the issue and a button to submit.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Problem'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  onChanged: (v) => setState(() => _selectedCategory = v),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Detail Text',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _feedbackController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Explain what happened or what isn\'t working...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Screenshot (Optional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 32, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      _selectedImagePath != null ? 'Image Attached' : 'Tap to Upload Screenshot',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Send Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

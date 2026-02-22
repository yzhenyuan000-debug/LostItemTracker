import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

class HelpAndFeedbackPage extends StatefulWidget {
  const HelpAndFeedbackPage({super.key});

  @override
  State<HelpAndFeedbackPage> createState() => _HelpAndFeedbackPageState();
}

class _HelpAndFeedbackPageState extends State<HelpAndFeedbackPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _selectedCategory = 'General Feedback';
  bool _isSubmitting = false;

  final List<String> _feedbackCategories = [
    'General Feedback',
    'Bug Report',
    'Feature Request',
    'Report Issue',
    'Question',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Changed from 3 to 4
    _loadUserEmail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feedbackController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _emailController.text = user.email ?? '';
      });
    }
  }

  Future<void> _submitFeedback() async {
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your feedback'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('user_feedback').add({
        'userId': user?.uid ?? 'anonymous',
        'email': _emailController.text.trim(),
        'category': _selectedCategory,
        'feedback': _feedbackController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'pointsAwarded': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted successfully! Thank you.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Clear form
        _feedbackController.clear();
        setState(() {
          _selectedCategory = 'General Feedback';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@tarumt.edu.my',
      query: 'subject=Lost%20Item%20Tracker%20Support',
    );

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open email app. Please install an email client.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _launchPhone() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '+60341450123');

    try {
      final launched = await launchUrl(
        phoneUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open phone app. Please check if phone app is available.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Feedback'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: false, // Make tabs scrollable for 4 tabs
          tabs: const [
            Tab(icon: Icon(Icons.help_outline), text: 'FAQ'),
            Tab(icon: Icon(Icons.feedback_outlined), text: 'Feedback'),
            Tab(icon: Icon(Icons.contact_support), text: 'Contact'),
            Tab(icon: Icon(Icons.info_outline), text: 'About Us'), // New tab
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFAQTab(),
          _buildFeedbackTab(),
          _buildContactTab(),
          _buildAboutUsTab(), // New tab content
        ],
      ),
    );
  }

  // ==================== FAQ TAB ====================
  Widget _buildFAQTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Frequently Asked Questions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Find answers to common questions',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),

        // FAQ items
        _buildFAQSection(
          title: 'Getting Started',
          icon: Icons.rocket_launch,
          color: Colors.blue,
          questions: [
            _FAQItem(
              question: 'How do I report a lost item?',
              answer:
              'Tap the "Report Item" button on the home screen or the "+" floating action button. Select "Lost Item" and fill in the details including item name, category, description, photo, and location.',
            ),
            _FAQItem(
              question: 'How do I report a found item?',
              answer:
              'Tap the "Report Item" button on the home screen or the "+" floating action button. Select "Found Item" and fill in the details. Make sure to include a clear photo and location where you found it.',
            ),
            _FAQItem(
              question: 'How can I search for my lost item?',
              answer:
              'Use the "Find Item" button on the home screen or tap "Search" in the bottom navigation. You can search by keywords, filter by category, date range, and sort results.',
            ),
          ],
        ),

        const SizedBox(height: 20),

        _buildFAQSection(
          title: 'Reports & Claims',
          icon: Icons.description,
          color: Colors.orange,
          questions: [
            _FAQItem(
              question: 'How do I claim a found item?',
              answer:
              'When you find your lost item in the search results, tap on it to view details. Then tap the "Claim This Item" button and fill in the claim form with proof of ownership.',
            ),
            _FAQItem(
              question: 'Can I edit my report after submitting?',
              answer:
              'Currently, you cannot edit a submitted report. If you need to make changes, please delete the report from "My Reports" and create a new one.',
            ),
            _FAQItem(
              question: 'How do I delete my report?',
              answer:
              'Go to "My Reports" from the home screen, find your report, and tap the delete icon. Confirm the deletion when prompted.',
            ),
          ],
        ),

        const SizedBox(height: 20),

        _buildFAQSection(
          title: 'Account & Settings',
          icon: Icons.person,
          color: Colors.green,
          questions: [
            _FAQItem(
              question: 'How do I update my profile?',
              answer:
              'Tap the account icon in the top right, then select "Profile". You can update your full name, campus ID, and email address.',
            ),
            _FAQItem(
              question: 'What is the QR Code for?',
              answer:
              'Your QR Code is your unique identifier. Security personnel can scan it to verify your identity when you\'re claiming an item.',
            ),
            _FAQItem(
              question: 'How do I change my password?',
              answer:
              'Currently, password changes must be done through the login page. Tap "Forgot Password" when logging in to receive a password reset email.',
            ),
          ],
        ),

        const SizedBox(height: 20),

        _buildFAQSection(
          title: 'Notifications',
          icon: Icons.notifications,
          color: Colors.purple,
          questions: [
            _FAQItem(
              question: 'When will I receive notifications?',
              answer:
              'You\'ll receive notifications when:\n• Someone claims your found item report\n• Your claim is approved or rejected\n• There\'s a match for your lost item\n• Important system updates',
            ),
            _FAQItem(
              question: 'How do I manage notifications?',
              answer:
              'Tap the notification icon in the bottom navigation to view all your notifications. You can mark them as read or delete them.',
            ),
          ],
        ),

        const SizedBox(height: 20),

        _buildFAQSection(
          title: 'Campus Map',
          icon: Icons.map,
          color: Colors.teal,
          questions: [
            _FAQItem(
              question: 'How do I use the campus map?',
              answer:
              'The campus map shows common locations where items are lost or found. You can tap on markers to see details and navigate to specific locations.',
            ),
            _FAQItem(
              question: 'Can I add a custom location?',
              answer:
              'Yes! When reporting an item, you can select "Other" in the location dropdown and enter a custom location description.',
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Still need help card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.indigo.shade700,
                Colors.indigo.shade500,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.help_center,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              const Text(
                'Still need help?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Contact our support team or submit feedback',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _tabController.animateTo(2); // Go to Contact tab
                      },
                      icon: const Icon(Icons.contact_support, size: 18),
                      label: const Text('Contact'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _tabController.animateTo(1); // Go to Feedback tab
                      },
                      icon: const Icon(Icons.feedback, size: 18),
                      label: const Text('Feedback'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.indigo.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFAQSection({
    required String title,
    required IconData icon,
    required MaterialColor color,
    required List<_FAQItem> questions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color.shade700),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...questions.map((faq) => _buildFAQCard(faq, color)),
      ],
    );
  }

  Widget _buildFAQCard(_FAQItem faq, MaterialColor color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.question_answer,
              size: 16,
              color: color.shade700,
            ),
          ),
          title: Text(
            faq.question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            const Divider(),
            const SizedBox(height: 8),
            Text(
              faq.answer,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FEEDBACK TAB ====================
  Widget _buildFeedbackTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Send Us Feedback',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We value your feedback! Help us improve the app.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 32),

        // Category
        Text(
          'Category',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: Colors.indigo.shade700),
              items: _feedbackCategories.map((category) {
                IconData icon;
                Color color;
                switch (category) {
                  case 'Bug Report':
                    icon = Icons.bug_report;
                    color = Colors.red;
                    break;
                  case 'Feature Request':
                    icon = Icons.lightbulb;
                    color = Colors.orange;
                    break;
                  case 'Report Issue':
                    icon = Icons.warning;
                    color = Colors.amber;
                    break;
                  case 'Question':
                    icon = Icons.help;
                    color = Colors.blue;
                    break;
                  default:
                    icon = Icons.feedback;
                    color = Colors.green;
                }

                return DropdownMenuItem<String>(
                  value: category,
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: color),
                      const SizedBox(width: 12),
                      Text(category),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Email
        Text(
          'Your Email',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'your.email@example.com',
            prefixIcon: Icon(Icons.email, color: Colors.indigo.shade700),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.indigo.shade700, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),

        const SizedBox(height: 24),

        // Feedback
        Text(
          'Your Feedback',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _feedbackController,
          maxLines: 8,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Tell us what you think...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.indigo.shade700, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            alignLabelWithHint: true,
          ),
        ),

        const SizedBox(height: 32),

        // Submit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitFeedback,
            icon: _isSubmitting
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Icon(Icons.send),
            label: Text(_isSubmitting ? 'Submitting...' : 'Submit Feedback'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your feedback is anonymous and helps us improve the app for everyone.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== CONTACT TAB ====================
  Widget _buildContactTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Contact Us',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Get in touch with our support team',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 32),

        // Contact methods
        _buildContactCard(
          icon: Icons.email,
          title: 'Email Support',
          subtitle: 'support@tarumt.edu.my',
          description: 'Send us an email for detailed inquiries',
          color: Colors.blue,
          onTap: _launchEmail,
        ),

        const SizedBox(height: 16),

        _buildContactCard(
          icon: Icons.phone,
          title: 'Phone Support',
          subtitle: '+60 3-4145 0123',
          description: 'Call us during office hours (9 AM - 5 PM)',
          color: Colors.green,
          onTap: _launchPhone,
        ),

        const SizedBox(height: 16),

        _buildContactCard(
          icon: Icons.location_on,
          title: 'Visit Us',
          subtitle: 'Security Office, Main Campus',
          description: 'Tunku Abdul Rahman University of Management and Technology\nJalan Genting Klang, Setapak\n53300 Kuala Lumpur',
          color: Colors.orange,
          onTap: null,
        ),

        const SizedBox(height: 32),

        // Office hours
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.indigo.shade700, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Office Hours',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildOfficeHourRow('Monday - Friday', '9:00 AM - 5:00 PM'),
              _buildOfficeHourRow('Saturday', '9:00 AM - 1:00 PM'),
              _buildOfficeHourRow('Sunday & Public Holidays', 'Closed'),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Quick links
        Text(
          'Quick Links',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),

        _buildQuickLinkCard(
          icon: Icons.description,
          title: 'User Guide',
          subtitle: 'Learn how to use the app',
          onTap: () {
            _tabController.animateTo(0); // Go to FAQ
          },
        ),

        const SizedBox(height: 12),

        _buildQuickLinkCard(
          icon: Icons.security,
          title: 'Privacy Policy',
          subtitle: 'How we protect your data',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Privacy Policy page coming soon'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        _buildQuickLinkCard(
          icon: Icons.gavel,
          title: 'Terms of Service',
          subtitle: 'App usage terms and conditions',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Terms of Service page coming soon'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),

        const SizedBox(height: 32),

        // Version info
        Center(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                'TARUMT Lost Item Tracker',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== ABOUT US TAB (NEW!) ====================
  Widget _buildAboutUsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'About Us',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Learn more about TARUMT Lost Item Tracker',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 40),

        // Rotating Logo Section
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.shade100,
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 40),

        // App Name
        Center(
          child: Text(
            'TARUMT Lost Item Tracker',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 32),

        // Mission Section
        _buildInfoCard(
          icon: Icons.flag,
          title: 'Our Mission',
          content:
          'To create a seamless and efficient platform that helps students, faculty, and staff reunite with their lost belongings quickly and easily. We believe that no item should be lost forever on campus.',
          color: Colors.blue,
        ),

        const SizedBox(height: 16),

        // Features Section
        _buildInfoCard(
          icon: Icons.star,
          title: 'Key Features',
          content:
          '• Easy lost & found reporting\n'
              '• Smart search with filters\n'
              '• Real-time notifications\n'
              '• Secure claim verification\n'
              '• Interactive campus map\n'
              '• Reward points system\n'
              '• QR code identification',
          color: Colors.orange,
        ),

        const SizedBox(height: 16),

        // Technology Section
        _buildInfoCard(
          icon: Icons.code,
          title: 'Built With',
          content:
          'This app is built using Flutter for cross-platform mobile development, powered by Firebase for real-time database, authentication, and cloud storage. We prioritize user privacy and data security.',
          color: Colors.green,
        ),

        const SizedBox(height: 16),

        // Community Section
        _buildInfoCard(
          icon: Icons.people,
          title: 'Our Community',
          content:
          'Join thousands of TARUMT students and staff who are making our campus a better place. Together, we\'re building a community where lost items find their way home.',
          color: Colors.purple,
        ),

        const SizedBox(height: 32),

        // Developer Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.indigo.shade700,
                Colors.indigo.shade500,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                Icons.school,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                'Tunku Abdul Rahman University\nof Management and Technology',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Developed with ❤️ for the TARUMT community',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Footer
        Center(
          child: Column(
            children: [
              Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '© 2024 TARUMT. All rights reserved.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required MaterialColor color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 24, color: color.shade700),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required MaterialColor color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color.shade700),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required MaterialColor color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: color.shade700),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: color.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficeHourRow(String day, String hours) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            hours,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinkCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: Colors.indigo.shade700, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper class for FAQ items
class _FAQItem {
  final String question;
  final String answer;

  _FAQItem({
    required this.question,
    required this.answer,
  });
}
// user_registration_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'email_verification_page.dart';
import 'package:flutter/services.dart';

class UserRegistrationPage extends StatefulWidget {
  const UserRegistrationPage({super.key});

  @override
  State<UserRegistrationPage> createState() => _UserRegistrationPageState();
}

class _UserRegistrationPageState extends State<UserRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _campusIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _campusIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // password rules:
  // at least one uppercase, one lowercase, one digit, one special char among @#\$%&*
  final RegExp _passwordRegExp =
  RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$%\^&\*\(\)_\+\-=~]).{6,}$');

  // email regex (basic, supports multi-level domains)
  final RegExp _emailRegExp = RegExp(r'^[\w\.\-+%]+@([\w\-]+\.)+[A-Za-z]{2,}$');

  // phone: digits only, length 10 or 11
  final RegExp _phoneRegExp = RegExp(r'^\d{10,11}$');

  Future<void> _proceedToNextPage() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms and Conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create user with Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to create user.');
      }

      final uid = user.uid;

      // Prepare data to save IMMEDIATELY to Firestore (do NOT include emailVerified)
      final userData = {
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'campusId': _campusIdController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'user',
      };

      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(userData);
        debugPrint('User data saved to Firestore for uid: $uid');
      } catch (fireErr) {
        debugPrint('Failed saving to Firestore: $fireErr');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning: failed saving profile. ${fireErr.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Send email verification
      await user.sendEmailVerification();

      // Navigate to verification page
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmailVerificationPage(
            email: _emailController.text.trim(),
            fullName: _fullNameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            campusId: _campusIdController.text.trim(),
            userId: uid,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      // show more detailed error to help debugging
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is invalid.';
          break;
        case 'operation-not-allowed':
          errorMessage =
          'Email/Password accounts are not enabled. Enable them in Firebase Console.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection.';
          break;
        default:
          errorMessage =
          'Error (${e.code}): ${e.message ?? 'An unknown error occurred.'}';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms and Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            '''
Terms and Conditions

Effective Date: January 20, 2026

Please read these Terms and Conditions ("Terms") carefully before using the TARUMT KL Campus Lost Item Tracker application ("App"). By accessing or using the App, you agree to be bound by these Terms. If you do not agree with any part of these Terms, do not use the App.

1. Definitions
  • "App" means the TARUMT KL Campus Lost Item Tracker mobile or web application.
  • "We", "us", or "our" refers to the administrators/operators of the App.
  • "You" or "User" means any person using the App.
  • "Content" means any text, images, photos, reports, comments, or other information posted or submitted via the App.

2. Acceptance of Terms
  By using the App you confirm that you are at least the minimum age required by applicable law and that you accept and agree to these Terms and any posted guidelines or rules. Use of the App indicates your acceptance of these Terms.

3. Eligibility and Account
  • To use certain features of the App you may need to register for an account. You agree to provide accurate, current, and complete information during registration and to keep your account information updated.
  • You are responsible for maintaining the confidentiality of your account credentials and for all activity that occurs under your account. Notify us immediately if you suspect any unauthorized use of your account.

4. User Responsibilities and Conduct
  • You must use the App in a lawful, honest, and respectful manner. Prohibited behaviour includes, but is not limited to: submitting false or misleading information, impersonating others, posting harmful or obscene material, attempting to access restricted areas, or using the App for commercial solicitation without permission.
  • You agree not to upload, post, or transmit any Content that violates privacy, intellectual property, or other rights of any person or entity.

5. Reporting Lost & Found Items
  • Users may report lost or found items using the App. You must provide accurate descriptions and contact details. The App is a community tool to help reunite items with owners; we do not guarantee recovery.
  • When you report an item, you agree that the information you provide may be shared with other users of the App and with campus staff as necessary to facilitate recovery.

6. Accuracy of Information
  • While we strive to maintain accurate and up-to-date information, we do not warrant that Content provided by users or third parties is accurate, complete, or reliable. You are responsible for verifying any information before acting on it.

7. Privacy
  • Use of the App is also governed by our Privacy Policy, which explains how we collect, use, and share personal data. By using the App you consent to the collection and use of this information as described in the Privacy Policy. (Link to Privacy Policy: https://example.com/privacy)

8. Intellectual Property
  • All intellectual property rights in the App's design, code, graphics, and content provided by us remain our property or the property of our licensors. You may not reproduce, distribute, or create derivative works from such materials without prior written permission.
  • By posting Content to the App you grant us a non-exclusive, worldwide, royalty-free license to use, copy, modify, display, and distribute that Content for the purpose of operating and improving the App and its services.

9. Prohibited Items and Actions
  • The App is not to be used to facilitate the sale or handling of illegal items or to coordinate unlawful activities. If you discover any item that may be illegal or dangerous, contact campus security immediately and do not use the App to handle the situation.

10. No Warranty
  • The App is provided “as is” and “as available” without warranties of any kind, whether express or implied. We do not warrant that the App will be uninterrupted, error-free, secure, or free from viruses or other harmful components.

11. Limitation of Liability
  • To the fullest extent permitted by law, we, our affiliates, officers, employees, or agents will not be liable for any indirect, incidental, special, punitive, or consequential damages arising from your use of the App, including loss of data, loss of profits, or costs of replacement services.

12. Indemnification
  • You agree to indemnify and hold harmless us and our representatives from any claim, loss, liability, cost, or expense (including reasonable legal fees) arising from your use of the App or any violation of these Terms.

13. Termination and Suspension
  • We may suspend or terminate your access to the App at any time, with or without notice, for conduct that we believe violates these Terms or is harmful to other users, campus property, or the App services.

14. Changes to the Terms and App
  • We reserve the right to modify or update these Terms at any time. When changes are made, we will update the Effective Date. Continued use of the App after such changes constitutes acceptance of the revised Terms.
  • We may also modify, suspend, or discontinue the App (or parts of it) at any time without liability to you.

15. Third-Party Services and Links
  • The App may contain links to third-party websites or services. We do not control these third parties and are not responsible for their content, privacy practices, or terms. Linking does not imply endorsement.

16. Governing Law and Dispute Resolution
  • These Terms are governed by the laws of Malaysia (or the jurisdiction you specify). Any dispute arising out of or relating to these Terms shall be resolved in the courts of the governing jurisdiction, unless otherwise agreed.

17. Severability
  • If any provision of these Terms is found to be invalid or unenforceable, the remaining provisions will continue in full force and effect.

18. Entire Agreement
  • These Terms, together with any other legal notices and the Privacy Policy, constitute the entire agreement between you and us concerning your use of the App.

19. Contact
  • If you have questions or concerns about these Terms, please contact us at:
    TARUMT KL Campus Lost Item Tracker Support
    Email: support@tarumtklcampuslostitemtracker.com
    Website: https://tarumtklcampuslostitemtracker.com

By using the App you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.
''',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            '''
Privacy Policy

Effective Date: January 20, 2026

Last Updated: January 20, 2026

1. Introduction
TARUMT KL Campus Lost Item Tracker (the "App") is committed to protecting your privacy. This Privacy Policy explains what information we collect, how we use and share it, and what choices you have regarding your personal information when you use the App. By using the App, you agree to the terms of this Privacy Policy.

2. Information We Collect
We collect the minimum information necessary to provide the App’s services and improve user experience. This may include:

  a. Account Information
     • Email address, display name or full name, student/staff ID (where provided), and password or authentication tokens when you create an account or sign in via a third-party provider (e.g., Firebase Authentication).

  b. Profile and Content
     • Information you voluntarily provide in your profile and any content you post (e.g., lost/found item reports, item descriptions, photos, location information included in a report).

  c. Usage and Device Data
     • Technical data automatically collected when you use the App, such as device type, operating system, app version, crash reports, IP address, and interaction events (pages visited, features used).

  d. Location Data
     • If you choose to include location when reporting an item (explicitly), that location may be stored with the report. We do not capture continuous background location without your clear consent.

  e. Cookies and Similar Technologies
     • We and our service providers may use cookies, local storage, and similar technologies to store preferences and analytics data.

3. How We Use Your Information
We use personal information for the following purposes:
  • To operate, maintain, and provide features of the App (e.g., enabling account login, posting and searching lost/found items).
  • To communicate with you about your account, reports, and important updates.
  • To analyze usage and improve the App’s performance and user experience.
  • To detect, investigate, and prevent fraud, abuse, security incidents, and other harmful activity.
  • To comply with legal obligations and respond to lawful requests by public authorities.

4. Legal Basis for Processing (where applicable)
Where data protection laws apply, our legal bases for processing may include:
  • Your consent (for optional features such as analytics or push notifications).
  • Performance of a contract (to provide the App’s services you requested).
  • Legitimate interests (to maintain and improve the App, ensure security).
  • Compliance with legal obligations.

5. Sharing and Disclosure
We will not sell your personal information. We may share information in the limited circumstances below:
  • With other users: Information you post in a lost/found report (description, photos, optional location, and contact methods you choose to share) will be visible to other App users and campus staff as needed to facilitate reunification.
  • Service Providers: With vendors and service providers who perform services for us (e.g., cloud hosting, analytics, push notifications). These providers are contractually required to protect your information.
  • Legal Requirements: If required by law or to respond to lawful requests by public authorities, or to protect rights, property, or safety.
  • In connection with a business transaction: If we reorganize, merge, or sell part or all of our assets, user information may be transferred as part of that transaction under similar privacy protections.

6. Data Security
We implement reasonable administrative, technical, and physical measures to protect personal information against unauthorized access, disclosure, alteration, and destruction. Examples include authentication, encryption in transit, and secure cloud storage configurations. However, no method of transmission or storage is completely secure—absolute security cannot be guaranteed.

7. Data Retention
We retain personal information only as long as necessary to provide the App’s services, comply with legal obligations, resolve disputes, and enforce our agreements. For example, account information and user-generated reports may be retained for the duration your account exists and for a reasonable period after account deletion for backup and auditing purposes.

8. Your Rights and Choices
Depending on your jurisdiction, you may have rights concerning your personal data, such as:
  • Access: Request a copy of the personal data we hold about you.
  • Correction: Request correction of inaccurate or incomplete information.
  • Deletion: Request deletion of your account and personal data (subject to legal retention requirements).
  • Restriction or objection: Request restriction of certain processing or object to processing based on legitimate interests.
  • Data portability: Request a machine-readable copy of certain data you provided.

To exercise any of these rights, please contact us using the contact details provided below. We may ask for proof of identity before responding to requests.

9. Children and Minors
The App is intended for use by the campus community. If you are under the minimum age required by applicable law to create an account in your jurisdiction, you must obtain parental or guardian consent before using the App. If we learn that personal information of a child below the applicable minimum age was collected without appropriate consent, we will take steps to delete such information as required by law.

10. Cookies, Analytics, and Third-Party Tools
We may use third-party analytics services and SDKs (e.g., Firebase Analytics) to collect usage metrics and crash reports. These services collect information such as device identifiers, usage statistics, and crash traces. You can opt out of some analytics features through device settings where available or by contacting us.

11. Third-Party Links and Content
The App may contain links to third-party websites or services that are not controlled by us. We are not responsible for the privacy practices or content of third parties. Visiting third-party sites is subject to their privacy policies and terms.

12. International Transfers
Your data may be stored and processed in servers located in different countries. Where data is transferred across borders, we will take commercially reasonable steps to ensure appropriate safeguards are in place in accordance with applicable laws.

13. Changes to This Privacy Policy
We may update this Privacy Policy from time to time. When we make material changes, we will update the “Last Updated” date and may provide additional notice (e.g., in-app notice). Continued use of the App after changes indicates acceptance of the revised policy.

14. How to Delete Your Account or Request Data Access
To request deletion, access, or correction of your data, contact us at the email address below. We will respond within a reasonable timeframe and may require verification of your identity.

15. Contact Information
If you have questions, concerns, or requests regarding this Privacy Policy, please contact:
TARUMT KL Campus Lost Item Tracker Support
Email: support@tarumtklcampuslostitemtracker.com
Website: https://tarumtklcampuslostitemtracker.com

16. Consent
By using the App, you consent to this Privacy Policy and the collection and use of your information as described.

17. Governing Law
This Privacy Policy is governed by the laws of the jurisdiction where the App operator is located (e.g., Malaysia). Any disputes relating to this Policy shall be subject to the exclusive jurisdiction of the courts of that jurisdiction, unless otherwise required by law.

Thank you for using the TARUMT KL Campus Lost Item Tracker. We are committed to protecting your privacy and helping you recover lost items safely and respectfully.
  ''',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    if (!_emailRegExp.hasMatch(value.trim())) return 'Please enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';
    if (!_passwordRegExp.hasMatch(value)) {
      return 'Password must be ≥6 and include uppercase, \nlowercase, digit and special character';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your phone number';
    if (!_phoneRegExp.hasMatch(value)) {
      return 'Phone must be digits only, length 10 or 11';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Bar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade700,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                'Step 1 of 2',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 30),

              Text(
                'Registration',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Please fill in your details',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 30),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Full Name
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        if (value.trim().length < 3) {
                          return 'Full name must be at least 3 characters';
                        }
                        if (value.trim().length > 50) {
                          return 'Full name cannot exceed 50 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Email Address
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: _validateEmail,
                    ),

                    const SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: _validatePhone,
                    ),

                    const SizedBox(height: 16),

                    // Student/Staff ID
                    TextFormField(
                      controller: _campusIdController,
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Student / Staff ID',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your ID';
                        }
                        if (value.length > 10) {
                          return 'ID cannot exceed 10 characters';
                        }
                        if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
                          return 'ID can contain only letters and numbers';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: _validatePassword,
                    ),

                    const SizedBox(height: 16),

                    // Confirm Password
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Terms and Conditions Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    onChanged: (value) {
                      setState(() {
                        _agreedToTerms = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                          children: [
                            const TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms and Conditions',
                              style: TextStyle(
                                color: Colors.indigo.shade700,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = _showTermsAndConditions,
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: Colors.indigo.shade700,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = _showPrivacyPolicy,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Proceed Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _proceedToNextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Proceed to Next Page',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

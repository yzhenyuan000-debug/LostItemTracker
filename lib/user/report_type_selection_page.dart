import 'package:flutter/material.dart';
import 'lost_item_reporting_page.dart';

class ReportTypeSelectionPage extends StatelessWidget {
  const ReportTypeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Item'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Instruction text
              Text(
                'What would you like to report?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Select one of the options below',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // I Lost an Item Card
              _buildReportCard(
                context: context,
                title: 'I Lost an Item',
                description: 'Report an item that you have lost on campus',
                icon: Icons.search_off,
                iconColor: Colors.blue.shade600,
                iconBackgroundColor: Colors.blue.shade50,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LostItemReportingPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // I Found an Item Card
              _buildReportCard(
                context: context,
                title: 'I Found an Item',
                description: 'Report an item that you have found on campus',
                icon: Icons.inventory_2_outlined,
                iconColor: Colors.orange.shade600,
                iconBackgroundColor: Colors.orange.shade50,
                onTap: () {
                  // TODO: Navigate to report_found_item_page.dart
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report Found Item page coming soon'),
                      behavior: SnackBarBehavior.floating,
                      margin: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 1,
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomAppBar(context),
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Color iconBackgroundColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon on the left
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 20),

            // Text in the middle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow icon on the right
            Icon(
              Icons.chevron_right,
              size: 28,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAppBar(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: SizedBox(
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, Icons.home, 'Home', false),
            _buildNavItem(context, Icons.search, 'Search', false),
            const SizedBox(width: 40), // Space for FAB
            _buildNavItem(context, Icons.notifications_outlined, 'Notification', false),
            _buildNavItem(context, Icons.person, 'Account', false),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, bool isSelected) {
    return InkWell(
      onTap: () {
        if (label == 'Home') {
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Navigation to $label coming soon'),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 1,
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade500,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'lost_item_report.dart';
import 'found_item_report.dart';

class ReportHistoryPage extends StatefulWidget {
  const ReportHistoryPage({super.key});

  @override
  State<ReportHistoryPage> createState() => _ReportHistoryPageState();
}

class _ReportHistoryPageState extends State<ReportHistoryPage> {
  String _selectedTab = 'lost'; // 'lost' or 'found'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report History'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Tab Selection
          Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    label: 'Lost Item Report',
                    isSelected: _selectedTab == 'lost',
                    onTap: () {
                      setState(() {
                        _selectedTab = 'lost';
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    label: 'Found Item Report',
                    isSelected: _selectedTab == 'found',
                    onTap: () {
                      setState(() {
                        _selectedTab = 'found';
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Report List
          Expanded(
            child: _selectedTab == 'lost'
                ? _buildLostItemReportList()
                : _buildFoundItemReportList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo.shade700 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildLostItemReportList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text('Please log in to view your report history'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lost_item_reports')
          .where('userId', isEqualTo: user.uid)
          .where('reportStatus', isEqualTo: 'submitted')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading reports: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final reports = snapshot.data?.docs ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No submitted lost item reports',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            final data = report.data() as Map<String, dynamic>;
            return _buildReportCard(
              context: context,
              reportId: report.id,
              data: data,
              reportType: 'lost',
            );
          },
        );
      },
    );
  }

  Widget _buildFoundItemReportList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text('Please log in to view your report history'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('found_item_reports')
          .where('userId', isEqualTo: user.uid)
          .where('reportStatus', isEqualTo: 'submitted')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading reports: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final reports = snapshot.data?.docs ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No submitted found item reports',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            final data = report.data() as Map<String, dynamic>;
            return _buildReportCard(
              context: context,
              reportId: report.id,
              data: data,
              reportType: 'found',
            );
          },
        );
      },
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required String reportId,
    required Map<String, dynamic> data,
    required String reportType, // 'lost' or 'found'
  }) {
    final itemName = data['itemName'] as String? ?? 'Untitled';
    final category = data['category'] as String? ?? 'Uncategorized';
    final createdAt = data['createdAt'] as Timestamp?;
    final itemReturnStatus = data['itemReturnStatus'] as String? ?? 'pending';

    // Convert photoBytes from List<dynamic> to Uint8List
    Uint8List? photoBytes;
    final photoBytesData = data['photoBytes'];
    if (photoBytesData != null) {
      if (photoBytesData is Uint8List) {
        photoBytes = photoBytesData;
      } else if (photoBytesData is List) {
        photoBytes = Uint8List.fromList(List<int>.from(photoBytesData));
      }
    }

    String formattedDate = 'Unknown date';
    if (createdAt != null) {
      formattedDate = DateFormat('MMM dd, yyyy HH:mm').format(createdAt.toDate());
    }

    // Status color and text
    Color statusColor;
    String statusText;
    switch (itemReturnStatus) {
      case 'returned':
        statusColor = Colors.green;
        statusText = 'Returned';
        break;
      case 'claimed':
        statusColor = Colors.green;
        statusText = 'Claimed';
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusText = 'Pending';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _openReportDetails(reportId, reportType);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Image or placeholder
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: photoBytes != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    photoBytes,
                    fit: BoxFit.cover,
                  ),
                )
                    : Icon(
                  Icons.image_not_supported,
                  color: Colors.grey.shade400,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),

              // Report info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: reportType == 'lost'
                                ? Colors.blue.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 12,
                              color: reportType == 'lost'
                                  ? Colors.blue.shade700
                                  : Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade400,
                ),
                onPressed: () {
                  _confirmDeleteReport(reportId, reportType, itemName);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openReportDetails(String reportId, String reportType) async {
    if (reportType == 'lost') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LostItemReportPage(reportId: reportId),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoundItemReportPage(reportId: reportId),
        ),
      );
    }
  }

  Future<void> _confirmDeleteReport(
      String reportId,
      String reportType,
      String itemName,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Report'),
          content: Text(
            'Are you sure you want to delete the report for "$itemName"? This action cannot be undone.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteReport(reportId, reportType);
    }
  }

  Future<void> _deleteReport(String reportId, String reportType) async {
    try {
      final collection = reportType == 'lost'
          ? 'lost_item_reports'
          : 'found_item_reports';

      await FirebaseFirestore.instance
          .collection(collection)
          .doc(reportId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting report: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'lost_item_report.dart';
import 'found_item_report.dart';
import 'lost_item_claim.dart';

// Lightweight data structure for history items
class _HistoryItem {
  final String reportId;
  final String itemName;
  final String category;
  final String itemReturnStatus;
  final DateTime? createdAt;
  final Uint8List? thumbnailBytes; // Compressed thumbnail only

  _HistoryItem({
    required this.reportId,
    required this.itemName,
    required this.category,
    required this.itemReturnStatus,
    required this.createdAt,
    this.thumbnailBytes,
  });
}

class ReportHistoryPage extends StatefulWidget {
  const ReportHistoryPage({super.key});

  @override
  State<ReportHistoryPage> createState() => _ReportHistoryPageState();
}

class _ReportHistoryPageState extends State<ReportHistoryPage> {
  String _selectedTab = 'lost'; // 'lost', 'found', or 'claims'

  // Manual loading state for each tab
  List<_HistoryItem>? _lostReports;
  List<_HistoryItem>? _foundReports;
  List<_HistoryItem>? _claimReports;

  bool _isLoadingLost = false;
  bool _isLoadingFound = false;
  bool _isLoadingClaims = false;

  bool _lostError = false;
  bool _foundError = false;
  bool _claimsError = false;

  @override
  void initState() {
    super.initState();
    _loadLostReports();
  }

  // Compress image bytes down to a small thumbnail
  Future<Uint8List?> _createThumbnail(Uint8List? photoBytes) async {
    if (photoBytes == null) return null;
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        photoBytes,
        targetWidth: 160,
        targetHeight: 160,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      const double targetSize = 80.0;
      final double scale = targetSize /
          (image.width > image.height ? image.width.toDouble() : image.height.toDouble());
      final int newWidth = (image.width * scale).toInt();
      final int newHeight = (image.height * scale).toInt();

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
        Paint(),
      );

      final ui.Picture picture = recorder.endRecording();
      final ui.Image thumbnailImage = await picture.toImage(newWidth, newHeight);
      final ByteData? byteData =
      await thumbnailImage.toByteData(format: ui.ImageByteFormat.png);

      image.dispose();
      thumbnailImage.dispose();
      codec.dispose();

      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadLostReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) setState(() { _isLoadingLost = true; _lostError = false; });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lost_item_reports')
          .where('userId', isEqualTo: user.uid)
          .where('reportStatus', isEqualTo: 'submitted')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final List<_HistoryItem> items = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Extract and compress photo
        Uint8List? photoBytes;
        final photoBytesData = data['photoBytes'];
        if (photoBytesData != null) {
          if (photoBytesData is Uint8List) {
            photoBytes = photoBytesData;
          } else if (photoBytesData is List) {
            photoBytes = Uint8List.fromList(List<int>.from(photoBytesData));
          }
        }

        final thumbnail = await _createThumbnail(photoBytes);

        items.add(_HistoryItem(
          reportId: doc.id,
          itemName: data['itemName'] ?? 'Untitled',
          category: data['category'] ?? 'Uncategorized',
          itemReturnStatus: data['itemReturnStatus'] ?? 'pending',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          thumbnailBytes: thumbnail,
        ));
      }

      if (mounted) setState(() {
        _lostReports = items;
        _isLoadingLost = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _lostError = true;
        _isLoadingLost = false;
      });
    }
  }

  Future<void> _loadFoundReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) setState(() { _isLoadingFound = true; _foundError = false; });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('found_item_reports')
          .where('userId', isEqualTo: user.uid)
          .where('reportStatus', isEqualTo: 'submitted')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final List<_HistoryItem> items = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Extract and compress photo
        Uint8List? photoBytes;
        final photoBytesData = data['photoBytes'];
        if (photoBytesData != null) {
          if (photoBytesData is Uint8List) {
            photoBytes = photoBytesData;
          } else if (photoBytesData is List) {
            photoBytes = Uint8List.fromList(List<int>.from(photoBytesData));
          }
        }

        final thumbnail = await _createThumbnail(photoBytes);

        items.add(_HistoryItem(
          reportId: doc.id,
          itemName: data['itemName'] ?? 'Untitled',
          category: data['category'] ?? 'Uncategorized',
          itemReturnStatus: data['itemReturnStatus'] ?? 'pending',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          thumbnailBytes: thumbnail,
        ));
      }

      if (mounted) setState(() {
        _foundReports = items;
        _isLoadingFound = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _foundError = true;
        _isLoadingFound = false;
      });
    }
  }

  Future<void> _loadClaimReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) setState(() { _isLoadingClaims = true; _claimsError = false; });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lost_item_claims')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final List<_HistoryItem> items = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();

        // For claims, try to get the proof photo
        Uint8List? photoBytes;
        final photoBytesData = data['proofPhotoBytes'];
        if (photoBytesData != null) {
          if (photoBytesData is Uint8List) {
            photoBytes = photoBytesData;
          } else if (photoBytesData is List) {
            photoBytes = Uint8List.fromList(List<int>.from(photoBytesData));
          }
        }

        final thumbnail = await _createThumbnail(photoBytes);

        // For claims, we need to get the item info from the found report
        String itemName = 'Claimed Item';
        String category = 'Unknown';

        // Try to load item info from the found report
        try {
          final foundItemReportId = data['foundItemReportId'] as String?;
          if (foundItemReportId != null) {
            final foundDoc = await FirebaseFirestore.instance
                .collection('found_item_reports')
                .doc(foundItemReportId)
                .get();

            if (foundDoc.exists) {
              final foundData = foundDoc.data()!;
              itemName = foundData['itemName'] ?? itemName;
              category = foundData['category'] ?? category;
            }
          }
        } catch (e) {
          print('Error loading found item info: $e');
        }

        items.add(_HistoryItem(
          reportId: doc.id,
          itemName: itemName,
          category: category,
          itemReturnStatus: data['claimStatus'] ?? 'pending',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          thumbnailBytes: thumbnail,
        ));
      }

      if (mounted) setState(() {
        _claimReports = items;
        _isLoadingClaims = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _claimsError = true;
        _isLoadingClaims = false;
      });
    }
  }

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
          // Tab Selection (3 tabs)
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
                    label: 'Lost Report',
                    isSelected: _selectedTab == 'lost',
                    onTap: () {
                      setState(() {
                        _selectedTab = 'lost';
                      });
                      if (_lostReports == null) {
                        _loadLostReports();
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    label: 'Found Report',
                    isSelected: _selectedTab == 'found',
                    onTap: () {
                      setState(() {
                        _selectedTab = 'found';
                      });
                      if (_foundReports == null) {
                        _loadFoundReports();
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    label: 'Claims',
                    isSelected: _selectedTab == 'claims',
                    onTap: () {
                      setState(() {
                        _selectedTab = 'claims';
                      });
                      if (_claimReports == null) {
                        _loadClaimReports();
                      }
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
                : _selectedTab == 'found'
                ? _buildFoundItemReportList()
                : _buildLostItemClaimList(),
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

    if (_isLoadingLost) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_lostError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading reports',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLostReports,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final reports = _lostReports ?? [];

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

    return RefreshIndicator(
      onRefresh: _loadLostReports,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final item = reports[index];
          return _buildReportCard(
            context: context,
            item: item,
            reportType: 'lost',
          );
        },
      ),
    );
  }

  Widget _buildFoundItemReportList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text('Please log in to view your report history'),
      );
    }

    if (_isLoadingFound) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_foundError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading reports',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFoundReports,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final reports = _foundReports ?? [];

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

    return RefreshIndicator(
      onRefresh: _loadFoundReports,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final item = reports[index];
          return _buildReportCard(
            context: context,
            item: item,
            reportType: 'found',
          );
        },
      ),
    );
  }

  Widget _buildLostItemClaimList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text('Please log in to view your claims'),
      );
    }

    if (_isLoadingClaims) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_claimsError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading claims',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadClaimReports,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final claims = _claimReports ?? [];

    if (claims.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No submitted claims',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadClaimReports,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: claims.length,
        itemBuilder: (context, index) {
          final item = claims[index];
          return _buildReportCard(
            context: context,
            item: item,
            reportType: 'claims',
          );
        },
      ),
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required _HistoryItem item,
    required String reportType, // 'lost', 'found', or 'claims'
  }) {
    String formattedDate = 'Unknown date';
    if (item.createdAt != null) {
      formattedDate = DateFormat('MMM dd, yyyy HH:mm').format(item.createdAt!);
    }

    // Status color and text
    Color statusColor;
    Color statusTextColor;
    String statusText;

    if (reportType == 'claims') {
      // For claims, use claimStatus values
      switch (item.itemReturnStatus) {
        case 'approved':
          statusColor = Colors.green;
          statusTextColor = Colors.green.shade700;
          statusText = 'Approved';
          break;
        case 'rejected':
          statusColor = Colors.red;
          statusTextColor = Colors.red.shade700;
          statusText = 'Rejected';
          break;
        case 'pending':
        default:
          statusColor = Colors.orange;
          statusTextColor = Colors.orange.shade700;
          statusText = 'Pending';
          break;
      }
    } else {
      // For reports, use itemReturnStatus values
      switch (item.itemReturnStatus) {
        case 'returned':
          statusColor = Colors.green;
          statusTextColor = Colors.green.shade700;
          statusText = 'Returned';
          break;
        case 'claimed':
          statusColor = Colors.green;
          statusTextColor = Colors.green.shade700;
          statusText = 'Claimed';
          break;
        case 'pending':
        default:
          statusColor = Colors.orange;
          statusTextColor = Colors.orange.shade700;
          statusText = 'Pending';
          break;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _openReportDetails(item.reportId, reportType);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Image or placeholder (using compressed thumbnail)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: item.thumbnailBytes != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    item.thumbnailBytes!,
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
                      item.itemName,
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
                                : reportType == 'found'
                                ? Colors.orange.shade50
                                : Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: reportType == 'lost'
                                  ? Colors.blue.shade700
                                  : reportType == 'found'
                                  ? Colors.orange.shade700
                                  : Colors.purple.shade700,
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
                              color: statusTextColor,
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

              // Delete button (only for reports, not claims)
              if (reportType != 'claims')
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                  ),
                  onPressed: () {
                    _confirmDeleteReport(item.reportId, reportType, item.itemName);
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
    } else if (reportType == 'found') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoundItemReportPage(reportId: reportId),
        ),
      );
    } else if (reportType == 'claims') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LostItemClaimPage(claimId: reportId),
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
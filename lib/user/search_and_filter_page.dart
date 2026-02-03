import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'lost_item_report.dart';
import 'found_item_report.dart';

class SearchAndFilterPage extends StatefulWidget {
  const SearchAndFilterPage({super.key});

  @override
  State<SearchAndFilterPage> createState() => _SearchAndFilterPageState();
}

class _SearchAndFilterPageState extends State<SearchAndFilterPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isFilterExpanded = false;
  bool _isSearching = false;

  // Search results
  List<_SearchResultItem>? _searchResults;
  bool _hasSearched = false;

  // Filter options
  Set<String> _selectedCategories = {};
  String _selectedReportType = 'all'; // 'all', 'lost', 'found'
  String _timeSortOption = 'none'; // 'none', 'latest', 'oldest'
  String _alphaSortOption = 'none'; // 'none', 'a-z', 'z-a'
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _allCategories = [
    'Electronics',
    'Clothing',
    'Accessories',
    'Documents',
    'Keys',
    'Bags',
    'Books',
    'Wallets',
    'Phones',
    'Laptops',
    'Others',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    if (_searchController.text.trim().isEmpty &&
        _selectedCategories.isEmpty &&
        _selectedReportType == 'all' &&
        _startDate == null &&
        _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a search term or apply filters'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = <_SearchResultItem>[];

      // Search in lost items if needed
      if (_selectedReportType == 'all' || _selectedReportType == 'lost') {
        final lostResults = await _searchInCollection(
          'lost_item_reports',
          'lost',
        );
        results.addAll(lostResults);
      }

      // Search in found items if needed
      if (_selectedReportType == 'all' || _selectedReportType == 'found') {
        final foundResults = await _searchInCollection(
          'found_item_reports',
          'found',
        );
        results.addAll(foundResults);
      }

      // Apply combined sorting: time sort first (if selected), then alphabetical sort (if selected)
      if (_timeSortOption != 'none' || _alphaSortOption != 'none') {
        results.sort((a, b) {
          // First apply time sorting if selected
          if (_timeSortOption == 'latest') {
            if (a.createdAt == null && b.createdAt == null) {
              // If both null, continue to alphabetical sort
            } else if (a.createdAt == null) return 1;
            else if (b.createdAt == null) return -1;
            else {
              final timeCompare = b.createdAt!.compareTo(a.createdAt!);
              if (timeCompare != 0) return timeCompare; // Different dates, return time sort
              // Same date, continue to alphabetical sort
            }
          } else if (_timeSortOption == 'oldest') {
            if (a.createdAt == null && b.createdAt == null) {
              // If both null, continue to alphabetical sort
            } else if (a.createdAt == null) return 1;
            else if (b.createdAt == null) return -1;
            else {
              final timeCompare = a.createdAt!.compareTo(b.createdAt!);
              if (timeCompare != 0) return timeCompare; // Different dates, return time sort
              // Same date, continue to alphabetical sort
            }
          }

          // Then apply alphabetical sorting if selected
          if (_alphaSortOption == 'a-z') {
            return a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase());
          } else if (_alphaSortOption == 'z-a') {
            return b.itemName.toLowerCase().compareTo(a.itemName.toLowerCase());
          }

          return 0; // No sorting applied or items are equal
        });
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      print('Search error: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<_SearchResultItem>> _searchInCollection(
      String collectionName,
      String reportType,
      ) async {
    Query query = FirebaseFirestore.instance
        .collection(collectionName)
        .where('reportStatus', isEqualTo: 'submitted');

    // Apply category filter
    if (_selectedCategories.isNotEmpty) {
      query = query.where('category', whereIn: _selectedCategories.toList());
    }

    // Apply date filter
    if (_startDate != null && _endDate != null) {
      final dateField = reportType == 'lost' ? 'lostDateTime' : 'foundDateTime';
      query = query
          .where(dateField, isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!))
          .where(dateField, isLessThanOrEqualTo: Timestamp.fromDate(_endDate!));
    }

    final snapshot = await query.limit(10).get();

    final results = <_SearchResultItem>[];
    final searchTerm = _searchController.text.trim().toLowerCase();

    int processedCount = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;

      // Text search filter
      if (searchTerm.isNotEmpty) {
        final itemName = (data['itemName'] as String? ?? '').toLowerCase();
        final itemDescription = (data['itemDescription'] as String? ?? '').toLowerCase();
        final locationDescription = (data['locationDescription'] as String? ?? '').toLowerCase();

        if (!itemName.contains(searchTerm) &&
            !itemDescription.contains(searchTerm) &&
            !locationDescription.contains(searchTerm)) {
          continue;
        }
      }

      // Convert photo and create thumbnail
      Uint8List? photoBytes;
      final photoBytesData = data['photoBytes'];
      if (photoBytesData != null) {
        if (photoBytesData is Uint8List) {
          photoBytes = photoBytesData;
        } else if (photoBytesData is List) {
          photoBytes = Uint8List.fromList(List<int>.from(photoBytesData));
        }
      }

      // Create thumbnail and immediately release original
      final thumbnail = await _createThumbnail(photoBytes);
      photoBytes = null; // Release original photo bytes immediately

      results.add(_SearchResultItem(
        reportId: doc.id,
        reportType: reportType,
        itemName: data['itemName'] as String? ?? 'Untitled',
        category: data['category'] as String? ?? 'Unknown',
        thumbnailBytes: thumbnail,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      ));

      processedCount++;
      // Allow GC to run every few documents
      if (processedCount % 3 == 0) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    return results;
  }

  Future<Uint8List?> _createThumbnail(Uint8List? photoBytes) async {
    if (photoBytes == null) return null;
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        photoBytes,
        targetWidth: 100,
        targetHeight: 100,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      const double targetSize = 50.0;
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
      print('Thumbnail creation error: $e');
      return null;
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedCategories.clear();
      _selectedReportType = 'all';
      _timeSortOption = 'none';
      _alphaSortOption = 'none';
      _startDate = null;
      _endDate = null;
      _searchController.clear();
      _searchResults = null;
      _hasSearched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Filter'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedCategories.isNotEmpty ||
              _selectedReportType != 'all' ||
              _timeSortOption != 'none' ||
              _alphaSortOption != 'none' ||
              _startDate != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear all filters',
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, description, or location...',
                    prefixIcon: Icon(Icons.search, color: Colors.indigo.shade700),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                        });
                      },
                    )
                        : null,
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
                  onChanged: (value) {
                    setState(() {});
                  },
                  onSubmitted: (value) {
                    _performSearch();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSearching ? null : _performSearch,
                        icon: _isSearching
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Icon(Icons.search),
                        label: Text(_isSearching ? 'Searching...' : 'Search'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isFilterExpanded = !_isFilterExpanded;
                        });
                      },
                      icon: Icon(
                        _isFilterExpanded ? Icons.expand_less : Icons.tune,
                        color: Colors.indigo.shade700,
                      ),
                      label: Text(
                        'Filters',
                        style: TextStyle(color: Colors.indigo.shade700),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        side: BorderSide(color: Colors.indigo.shade700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filter Section
          if (_isFilterExpanded)
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Report Type Filter
                    _buildFilterTitle('Report Type'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildReportTypeChip('All', 'all'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildReportTypeChip('Lost', 'lost'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildReportTypeChip('Found', 'found'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Category Filter
                    _buildFilterTitle('Categories'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allCategories.map((category) {
                        final isSelected = _selectedCategories.contains(category);
                        return FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedCategories.add(category);
                              } else {
                                _selectedCategories.remove(category);
                              }
                            });
                          },
                          selectedColor: Colors.indigo.shade100,
                          checkmarkColor: Colors.indigo.shade700,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade700,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Date Range Filter
                    _buildFilterTitle('Date Range'),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectDateRange,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.date_range,
                              color: Colors.indigo.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _startDate != null && _endDate != null
                                    ? '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}'
                                    : 'Select date range',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _startDate != null
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ),
                            if (_startDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _startDate = null;
                                    _endDate = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Sort By Time
                    _buildFilterTitle('Sort By Time'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSortChip('None', 'none', Icons.clear, isTimeSort: true),
                        _buildSortChip('Latest', 'latest', Icons.access_time, isTimeSort: true),
                        _buildSortChip('Oldest', 'oldest', Icons.history, isTimeSort: true),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Sort By Alphabet
                    _buildFilterTitle('Sort By Alphabet'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSortChip('None', 'none', Icons.clear, isTimeSort: false),
                        _buildSortChip('A-Z', 'a-z', Icons.sort_by_alpha, isTimeSort: false),
                        _buildSortChip('Z-A', 'z-a', Icons.sort, isTimeSort: false),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Results Section
          Expanded(
            child: _buildResultsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildSortChip(String label, String value, IconData icon, {required bool isTimeSort}) {
    final isSelected = isTimeSort
        ? _timeSortOption == value
        : _alphaSortOption == value;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (isTimeSort) {
            _timeSortOption = value;
          } else {
            _alphaSortOption = value;
          }
        });
      },
      selectedColor: Colors.indigo.shade700,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildReportTypeChip(String label, String value) {
    final isSelected = _selectedReportType == value;
    return ChoiceChip(
      label: SizedBox(
        width: double.infinity,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedReportType = value;
        });
      },
      selectedColor: Colors.indigo.shade700,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildResultsSection() {
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Start searching for items',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter keywords or apply filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching...'),
          ],
        ),
      );
    }

    final results = _searchResults ?? [];

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${results.length} result${results.length == 1 ? '' : 's'} found',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              return _buildResultCard(results[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(_SearchResultItem item) {
    final isLost = item.reportType == 'lost';
    final Color accentColor = isLost ? Colors.blue.shade600 : Colors.orange.shade600;
    final Color bgColor = isLost ? Colors.blue.shade50 : Colors.orange.shade50;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          if (isLost) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LostItemReportPage(reportId: item.reportId),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FoundItemReportPage(reportId: item.reportId),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade100,
                  child: item.thumbnailBytes != null
                      ? Image.memory(
                    item.thumbnailBytes!,
                    fit: BoxFit.cover,
                  )
                      : Icon(
                    isLost ? Icons.search_off : Icons.inventory_2_outlined,
                    size: 28,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isLost ? 'Lost Item' : 'Found Item',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Item name
                    Text(
                      item.itemName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Category
                    Row(
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    if (item.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd, yyyy').format(item.createdAt!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultItem {
  final String reportId;
  final String reportType; // 'lost' or 'found'
  final String itemName;
  final String category;
  final Uint8List? thumbnailBytes;
  final DateTime? createdAt;

  _SearchResultItem({
    required this.reportId,
    required this.reportType,
    required this.itemName,
    required this.category,
    this.thumbnailBytes,
    this.createdAt,
  });
}
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'select_found_location_map.dart';
import 'found_item_reporting_success_page.dart';
import 'user_home_page.dart';
import 'item_matching_service.dart';

// ==================== FIRESTORE SIZE CONSTANTS ====================
// These constants ensure we stay within Firestore document size limits
const int FIRESTORE_DOC_LIMIT_BYTES = 1048576;  // 1 MiB
const int SAFE_DOC_BYTES = 1000000;              // Safe threshold
const int OVERHEAD_RESERVE_BYTES = 20000;        // Reserve for Firestore overhead
const int MIN_IMAGE_BYTES = 10000;               // Minimum viable image size

// ==================== DROP-OFF DESK MODEL ====================
class DropOffDesk {
  final String id;
  final String name;
  final String description;
  final String operatingHours;
  final String contact;
  final double latitude;
  final double longitude;
  final String colorHex;
  final bool isActive;

  DropOffDesk({
    required this.id,
    required this.name,
    required this.description,
    required this.operatingHours,
    required this.contact,
    required this.latitude,
    required this.longitude,
    required this.colorHex,
    required this.isActive,
  });

  factory DropOffDesk.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DropOffDesk(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      operatingHours: data['operatingHours'] ?? '',
      contact: data['contact'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      colorHex: data['colorHex'] ?? '#3F51B5',
      isActive: data['isActive'] ?? true,
    );
  }

  Color get color {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.indigo.shade700;
    }
  }
}

class FoundItemReportingPage extends StatefulWidget {
  const FoundItemReportingPage({super.key});

  @override
  State<FoundItemReportingPage> createState() => _FoundItemReportingPageState();
}

class _FoundItemReportingPageState extends State<FoundItemReportingPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _compressedImageBytes;
  String? _selectedCategory;
  final _itemNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  double? _latitude;
  double? _longitude;
  double? _locationRadius;
  String? _selectedAddress;
  final _locationDescriptionController = TextEditingController();
  DateTime? _foundDateTime;
  bool _isCompressingImage = false;
  bool _isSubmitting = false;

  // Drop-off desk selection
  String? _selectedDropOffDeskId;
  List<DropOffDesk> _dropOffDesks = [];
  bool _isLoadingDesks = true;

  final List<String> _categories = [
    'Electronics',
    'Documents',
    'Clothing',
    'Accessories',
    'Keys',
    'Bags',
    'Cards',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _loadDropOffDesks();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _descriptionController.dispose();
    _locationDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadDropOffDesks() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('dropOffDesks')
          .where('isActive', isEqualTo: true)
          .get();

      if (mounted) {
        setState(() {
          _dropOffDesks = snapshot.docs
              .map((doc) => DropOffDesk.fromFirestore(doc))
              .toList();
          _isLoadingDesks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDesks = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading drop-off desks: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Photo Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.indigo),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.indigo),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.camera);
                },
              ),
              if (_compressedImageBytes != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _compressedImageBytes = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() {
          _isCompressingImage = true;
        });

        final bytes = await pickedFile.readAsBytes();

        // Initial compression for preview (not final)
        final compressed = await _compressImageInitial(bytes);

        if (mounted) {
          setState(() {
            _compressedImageBytes = compressed;
            _isCompressingImage = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCompressingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Initial compression for image preview (moderate quality)
  /// Final compression will be done during submission based on document size
  Future<Uint8List> _compressImageInitial(Uint8List bytes) async {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    img.Image image = decoded;

    // Moderate initial compression for preview
    int quality = 85;
    Uint8List compressed =
    Uint8List.fromList(img.encodeJpg(image, quality: quality));

    const int maxSizeBytes = 800000; // 800KB for preview

    while (compressed.length > maxSizeBytes && quality > 30) {
      quality -= 10;
      compressed =
          Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }

    if (compressed.length > maxSizeBytes) {
      int targetWidth = 1200;
      while (compressed.length > maxSizeBytes && targetWidth > 400) {
        image = img.copyResize(image, width: targetWidth);
        compressed =
            Uint8List.fromList(img.encodeJpg(image, quality: 75));
        targetWidth -= 100;
      }
    }

    return compressed;
  }

  /// Smart compression to fit within Firestore document size limits
  /// This function compresses the image to a specific max size in bytes
  Future<Uint8List> _compressImageToMax(
      Uint8List bytes, {
        required int maxBytes,
      }) async {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    img.Image image = decoded;

    // Phase 1: Reduce quality from 90 to 10
    int quality = 90;
    Uint8List compressed =
    Uint8List.fromList(img.encodeJpg(image, quality: quality));

    while (compressed.lengthInBytes > maxBytes && quality > 10) {
      quality -= 10;
      compressed =
          Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }

    // Phase 2: If still too large, reduce dimensions by 80% iteratively
    int targetWidth = image.width;
    while (compressed.lengthInBytes > maxBytes && targetWidth > 200) {
      targetWidth = (targetWidth * 0.8).round();
      final resized = img.copyResize(image, width: targetWidth);

      // Try to compress the resized image
      int q = 80;
      Uint8List comp =
      Uint8List.fromList(img.encodeJpg(resized, quality: q));

      while (comp.lengthInBytes > maxBytes && q > 10) {
        q -= 10;
        comp = Uint8List.fromList(img.encodeJpg(resized, quality: q));
      }

      compressed = comp;
      image = resized;
    }

    return compressed;
  }

  /// Calculate the size of all non-image fields in bytes
  /// This helps us determine how much space is available for the image
  int _calculateOtherFieldsSize({
    required String userId,
    required String category,
    required String itemName,
    required String itemDescription,
    required double latitude,
    required double longitude,
    required double locationRadius,
    String? address,
    required String locationDescription,
    required DateTime foundDateTime,
    required String dropOffDeskId,
    required String reportStatus,
    String? itemReturnStatus,
  }) {
    // Create a map with all non-image fields
    final otherFields = {
      'userId': userId,
      'category': category,
      'itemName': itemName,
      'itemDescription': itemDescription,
      'latitude': latitude,
      'longitude': longitude,
      'locationRadius': locationRadius,
      'address': address,
      'locationDescription': locationDescription,
      'foundDateTime': foundDateTime.toIso8601String(),
      'dropOffDeskId': dropOffDeskId,
      'reportStatus': reportStatus,
      'createdAt': DateTime.now().toIso8601String(), // Placeholder
    };

    if (itemReturnStatus != null) {
      otherFields['itemReturnStatus'] = itemReturnStatus;
    }

    // Convert to JSON and encode to UTF-8 to get byte size
    final jsonString = jsonEncode(otherFields);
    final bytes = utf8.encode(jsonString);

    return bytes.length;
  }

  Future<void> _selectLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => SelectFoundLocationMapPage(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialRadius: _locationRadius,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result['latitude'] as double?;
        _longitude = result['longitude'] as double?;
        _locationRadius = result['radius'] as double?;
        _selectedAddress = result['address'] as String?;
      });
    }
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo.shade700,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.indigo.shade700,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _foundDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an item category'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (_compressedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a photo of the found item'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a location'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (_foundDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date and time'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (_selectedDropOffDeskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a drop-off desk'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _submitReport() async {
    if (!_validateForm()) {
      return;
    }

    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Submission'),
          content: const Text('Are you sure you want to submit this found item report?'),
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
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get current user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // ==================== SMART IMAGE COMPRESSION ====================
      // Step 1: Calculate the size of all non-image fields
      final otherFieldsBytes = _calculateOtherFieldsSize(
        userId: user.uid,
        category: _selectedCategory!,
        itemName: _itemNameController.text.trim(),
        itemDescription: _descriptionController.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
        locationRadius: _locationRadius ?? 50.0,
        address: _selectedAddress,
        locationDescription: _locationDescriptionController.text.trim(),
        foundDateTime: _foundDateTime!,
        dropOffDeskId: _selectedDropOffDeskId!,
        reportStatus: 'submitted',
        itemReturnStatus: 'pending',
      );

      print('Other fields size: $otherFieldsBytes bytes');

      // Step 2: Calculate maximum allowed bytes for image
      final allowedForImage = SAFE_DOC_BYTES - otherFieldsBytes - OVERHEAD_RESERVE_BYTES;

      print('Allowed for image: $allowedForImage bytes');

      // Step 3: Validate that we have enough space for an image
      if (allowedForImage < MIN_IMAGE_BYTES) {
        throw Exception(
            'Document size exceeded. The text fields are too large to include an image. '
                'Please reduce description length.'
        );
      }

      // Step 4: Compress image if needed
      Uint8List finalImageBytes;
      final currentImageSize = _compressedImageBytes!.lengthInBytes;
      print('Current image size: $currentImageSize bytes');

      if (currentImageSize <= allowedForImage) {
        // Image is already within limits
        finalImageBytes = _compressedImageBytes!;
        print('Image within limits, no further compression needed');
      } else {
        // Need to compress image to fit
        print('Compressing image to fit within $allowedForImage bytes...');

        finalImageBytes = await _compressImageToMax(
          _compressedImageBytes!,
          maxBytes: allowedForImage,
        );

        final compressedSize = finalImageBytes.lengthInBytes;
        print('Image compressed to $compressedSize bytes');

        // Verify compression was successful
        if (compressedSize > allowedForImage) {
          throw Exception(
              'Unable to compress image sufficiently. Please try a different photo.'
          );
        }
      }

      // Step 5: Prepare data for Firestore
      final reportData = {
        'userId': user.uid,
        'category': _selectedCategory!,
        'itemName': _itemNameController.text.trim(),
        'itemDescription': _descriptionController.text.trim(),
        'photoBytes': finalImageBytes, // Using compressed Uint8List
        'latitude': _latitude!,
        'longitude': _longitude!,
        'locationRadius': _locationRadius ?? 50.0,
        'address': _selectedAddress,
        'locationDescription': _locationDescriptionController.text.trim(),
        'foundDateTime': Timestamp.fromDate(_foundDateTime!),
        'dropOffDeskId': _selectedDropOffDeskId!,
        'reportStatus': 'submitted',
        'itemReturnStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Step 6: Final size validation (for debugging)
      final estimatedTotalSize = otherFieldsBytes +
          finalImageBytes.lengthInBytes +
          OVERHEAD_RESERVE_BYTES;
      print('Estimated total document size: $estimatedTotalSize bytes');

      if (estimatedTotalSize > SAFE_DOC_BYTES) {
        throw Exception(
            'Document size validation failed. Estimated size: $estimatedTotalSize bytes. '
                'Please contact support.'
        );
      }

      // Step 7: Add to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('found_item_reports')
          .add(reportData);

      print('Report submitted successfully with ID: ${docRef.id}');

      try {
        print('Starting matching process for found item...');
        final matchingService = ItemMatchingService();
        await matchingService.matchFoundItem(docRef.id);
        print('Matching process completed');
      } catch (e) {
        print('Error during matching: $e');
      }

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      // Navigate to success page with reportId
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => FoundItemReportingSuccessPage(
            reportId: docRef.id,
          ),
        ),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      print('Error submitting report: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting report: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _saveAsDraft() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get current user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // For drafts, we apply the same smart compression logic
      // but we're more lenient about incomplete data
      Uint8List? finalImageBytes;

      if (_compressedImageBytes != null &&
          _selectedCategory != null &&
          _latitude != null &&
          _longitude != null &&
          _foundDateTime != null &&
          _selectedDropOffDeskId != null) {

        // Calculate sizes for draft
        final otherFieldsBytes = _calculateOtherFieldsSize(
          userId: user.uid,
          category: _selectedCategory!,
          itemName: _itemNameController.text.trim(),
          itemDescription: _descriptionController.text.trim(),
          latitude: _latitude!,
          longitude: _longitude!,
          locationRadius: _locationRadius ?? 50.0,
          address: _selectedAddress,
          locationDescription: _locationDescriptionController.text.trim(),
          foundDateTime: _foundDateTime!,
          dropOffDeskId: _selectedDropOffDeskId!,
          reportStatus: 'draft',
        );

        final allowedForImage = SAFE_DOC_BYTES - otherFieldsBytes - OVERHEAD_RESERVE_BYTES;

        if (allowedForImage >= MIN_IMAGE_BYTES) {
          final currentImageSize = _compressedImageBytes!.lengthInBytes;

          if (currentImageSize <= allowedForImage) {
            finalImageBytes = _compressedImageBytes;
          } else {
            finalImageBytes = await _compressImageToMax(
              _compressedImageBytes!,
              maxBytes: allowedForImage,
            );
          }
        } else {
          // Skip image if not enough space
          finalImageBytes = null;
          print('Not enough space for image in draft, skipping image');
        }
      } else {
        // Incomplete draft, just save the image as-is (or skip if too large)
        if (_compressedImageBytes != null &&
            _compressedImageBytes!.lengthInBytes < 900000) {
          finalImageBytes = _compressedImageBytes;
        }
      }

      // Prepare data for Firestore
      final draftData = {
        'userId': user.uid,
        'category': _selectedCategory,
        'itemName': _itemNameController.text.trim(),
        'itemDescription': _descriptionController.text.trim(),
        'photoBytes': finalImageBytes,
        'latitude': _latitude,
        'longitude': _longitude,
        'locationRadius': _locationRadius,
        'address': _selectedAddress,
        'locationDescription': _locationDescriptionController.text.trim(),
        'foundDateTime': _foundDateTime != null ? Timestamp.fromDate(_foundDateTime!) : null,
        'dropOffDeskId': _selectedDropOffDeskId,
        'reportStatus': 'draft',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add to Firestore
      await FirebaseFirestore.instance
          .collection('found_item_reports')
          .add(draftData);

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report saved as draft successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Navigate to home page
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const UserHomePage(),
        ),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving draft: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatRadius(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Found Item'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Photos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: FractionallySizedBox(
                            widthFactor: 1.0,
                            child: InkWell(
                              onTap: _isCompressingImage ? null : _pickImage,
                              borderRadius: BorderRadius.circular(12),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final maxHeight =
                                      MediaQuery.of(context).size.height * 0.5;

                                  return ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: maxHeight,
                                      maxWidth: constraints.maxWidth,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _compressedImageBytes != null
                                              ? Colors.indigo.shade50
                                              : Colors.indigo.shade50,
                                          width: 2,
                                        ),
                                      ),
                                      child: _isCompressingImage
                                          ? const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(),
                                            SizedBox(height: 12),
                                            Text('Compressing image...'),
                                          ],
                                        ),
                                      )
                                          : _compressedImageBytes != null
                                          ? ClipRRect(
                                        borderRadius:
                                        BorderRadius.circular(12),
                                        child: Image.memory(
                                          _compressedImageBytes!,
                                          fit: BoxFit.contain,
                                          width: double.infinity,
                                        ),
                                      )
                                          : Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo,
                                            size: 48,
                                            color:
                                            Colors.indigo.shade700,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Tap to upload photo',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color:
                                              Colors.indigo.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '(Required)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.indigo.shade600,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'Item Category',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          hint: const Text('Select a category'),
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a category';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'Item Name',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _itemNameController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Black iPhone 13',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter the item name';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'Detailed Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: 'Describe the item in detail (color, brand, special marks, etc.)',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a detailed description';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'Where did you find it?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Center(
                          child: FractionallySizedBox(
                            widthFactor: 1.0,
                            child: InkWell(
                              onTap: _selectLocation,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 120,
                                  maxHeight: 180,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.indigo.shade50,
                                    width: 2,
                                  ),
                                ),
                                child: _latitude != null && _longitude != null
                                    ? Center(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 40,
                                          color: Colors.indigo.shade700,
                                        ),
                                        const SizedBox(height: 6),
                                        Flexible(
                                          child: Text(
                                            _selectedAddress ?? 'Location selected',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.indigo.shade800,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Flexible(
                                          child: Text(
                                            'Lat: ${_latitude!.toStringAsFixed(5)}, '
                                                'Lng: ${_longitude!.toStringAsFixed(5)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.indigo.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (_locationRadius != null) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.radio_button_unchecked,
                                                  size: 12,
                                                  color: Colors.red.shade700,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Range: ${_formatRadius(_locationRadius!)}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.red.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                )
                                    : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_location,
                                      size: 48,
                                      color: Colors.indigo.shade700,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Tap to select location',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.indigo.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'Location Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _locationDescriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'e.g. Near the library entrance, beside the vending machine',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a location description';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'When did you find it?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _selectDateTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _foundDateTime != null
                                    ? Colors.indigo.shade700
                                    : Colors.grey.shade400,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: _foundDateTime != null
                                      ? Colors.indigo.shade700
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _foundDateTime != null
                                      ? DateFormat('yyyy-MM-dd HH:mm').format(_foundDateTime!)
                                      : 'Select date and time',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _foundDateTime != null
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade600,
                                    fontWeight: _foundDateTime != null
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ==================== DROP-OFF DESK SELECTION ====================
                        Text(
                          'Where will you deposit it?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_isLoadingDesks)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_dropOffDesks.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No drop-off desks available at the moment.',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._dropOffDesks.map((desk) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedDropOffDeskId = desk.id;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _selectedDropOffDeskId == desk.id
                                        ? desk.color.withOpacity(0.1)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedDropOffDeskId == desk.id
                                          ? desk.color
                                          : Colors.grey.shade300,
                                      width: _selectedDropOffDeskId == desk.id ? 2 : 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Radio<String>(
                                          value: desk.id,
                                          groupValue: _selectedDropOffDeskId,
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedDropOffDeskId = value;
                                            });
                                          },
                                          activeColor: desk.color,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                desk.name,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                desk.description,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                ),
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
                                                      desk.operatingHours,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.phone,
                                                    size: 14,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    desk.contact,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),

                        const SizedBox(height: 40),

                        // Submit Report Button
                        Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.8,
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitReport,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo.shade700,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  disabledBackgroundColor: Colors.grey.shade400,
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                                    : const Text(
                                  'Submit Report',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Save as Draft Button
                        Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.8,
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                onPressed: _isSubmitting ? null : _saveAsDraft,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.indigo.shade700,
                                  side: BorderSide(
                                    color: Colors.indigo.shade700,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  disabledForegroundColor: Colors.grey.shade400,
                                ),
                                child: _isSubmitting
                                    ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.indigo.shade700),
                                  ),
                                )
                                    : const Text(
                                  'Save as Draft',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
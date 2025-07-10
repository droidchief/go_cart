import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/product.dart';

/// Enhanced ProductCard widget with improved UI and sync indicators
/// Displays product information with editable fields and change tracking
class ProductCard extends StatefulWidget {
  final Product product;
  final Function(Product) onProductSaved;
  final Function(int) onProductDeleted;
  final Function(Product)? onSubtotalChanged;

  const ProductCard({
    super.key,
    required this.product,
    required this.onProductSaved,
    required this.onProductDeleted,
    this.onSubtotalChanged,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late TextEditingController _countController;
  late TextEditingController _mrpController;
  late TextEditingController _ppController;
  late String _selectedPackagingType;
  late String _selectedImagePath;

  bool _hasUnsavedChanges = false;
  bool _isEditing = false;

  late Product _currentProduct;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _currentProduct = widget.product;

    _countController = TextEditingController(
      text: widget.product.count.toString(),
    );
    _mrpController = TextEditingController(
      text: widget.product.mrp.toStringAsFixed(2),
    );
    _ppController = TextEditingController(
      text: widget.product.pp.toStringAsFixed(2),
    );
    _selectedPackagingType = widget.product.packagingType;
    _selectedImagePath = widget.product.imagePath;

    // Add listeners to detect changes

    _countController.addListener(_onCountChanged);
    _mrpController.addListener(_onMrpChanged);
    _ppController.addListener(_onPpChanged);
  }

  void _onCountChanged() {
    final newCount = int.tryParse(_countController.text) ?? 0;
    if (newCount != _currentProduct.count) {
      setState(() {
        _currentProduct = _currentProduct.copyWith(count: newCount);
        _hasUnsavedChanges = true;
      });
      _notifyParentOfSubtotalChange();
    }
  }

  void _onPpChanged() {
    final newPp = double.tryParse(_ppController.text) ?? 0.0;
    if (newPp != _currentProduct.pp) {
      setState(() {
        _currentProduct = _currentProduct.copyWith(pp: newPp);
        _hasUnsavedChanges = true;
      });
      _notifyParentOfSubtotalChange();
    }
  }

  void _onMrpChanged() {
    final newMrp = double.tryParse(_mrpController.text) ?? 0.0;
    if (newMrp != _currentProduct.mrp) {
      setState(() {
        _currentProduct = _currentProduct.copyWith(mrp: newMrp);
        _hasUnsavedChanges = true;
      });
    }
  }

  void _notifyParentOfSubtotalChange() {
    if (widget.onSubtotalChanged != null) {
      widget.onSubtotalChanged!(_currentProduct);
    }
  }

  // void _onFieldChanged() {
  //   if (!_hasUnsavedChanges) {
  //     setState(() {
  //       _hasUnsavedChanges = true;
  //     });
  //   }
  // }

  @override
  void didUpdateWidget(ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product != widget.product) {
      _updateControllers();
    }
  }

  void _updateControllers() {
    _countController.text = widget.product.count.toString();
    _mrpController.text = widget.product.mrp.toStringAsFixed(2);
    _ppController.text = widget.product.pp.toStringAsFixed(2);
    _selectedPackagingType = widget.product.packagingType;
    _selectedImagePath = widget.product.imagePath;
    _hasUnsavedChanges = false;
    _isEditing = false;
  }

  @override
  void dispose() {
    _countController.dispose();
    _mrpController.dispose();
    _ppController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            _hasUnsavedChanges
                ? BorderSide(color: Colors.orange, width: 2)
                : BorderSide.none,
      ),
      child: Column(
        children: [
          // Header with product name and sync status
          _buildHeader(),

          // Product image (clickable)
          _buildProductImage(),

          // Editable fields
          _buildEditableFields(),

          // Sub total section
          _buildSubTotalSection(),

          // Save/Cancel buttons (only show when editing)
          if (_isEditing && _hasUnsavedChanges) _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _hasUnsavedChanges ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_hasUnsavedChanges)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Unsaved',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Updated by: ${widget.product.updatedBy} • v${widget.product.version}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          _buildSyncStatusBadge(),
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            color: _isEditing ? Colors.red : Colors.blue,
            onPressed: () {
              if (_isEditing && _hasUnsavedChanges) {
                _showDiscardChangesDialog();
              } else {
                setState(() {
                  _isEditing = !_isEditing;
                });
              }
            },
            tooltip: _isEditing ? 'Cancel Editing' : 'Edit Product',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeleteConfirmation(),
            tooltip: 'Delete Product',
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusBadge() {
    final now = DateTime.now();
    final difference = now.difference(widget.product.lastUpdated).inMinutes;

    Color badgeColor;
    String badgeText;

    if (difference < 1) {
      badgeColor = Colors.green;
      badgeText = 'Just updated';
    } else if (difference < 60) {
      badgeColor = Colors.orange;
      badgeText = '${difference}m ago';
    } else {
      badgeColor = Colors.grey;
      badgeText = 'Synced';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        badgeText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    return GestureDetector(
      onTap: _isEditing ? _pickImage : null,
      child: Container(
        height: 120,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isEditing ? Colors.blue.shade300 : Colors.grey.shade300,
            width: _isEditing ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildImageWidget(),
            ),
            if (_isEditing)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    if (_selectedImagePath.isEmpty) {
      return _buildImagePlaceholder();
    }

    // Check if it's a URL or local file path
    if (_selectedImagePath.startsWith('http')) {
      // Network image
      return Image.network(
        _selectedImagePath,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildImagePlaceholder();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value:
                  loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
            ),
          );
        },
      );
    } else {
      // Local file
      final file = File(_selectedImagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildImagePlaceholder();
          },
        );
      } else {
        return _buildImagePlaceholder();
      }
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            _isEditing ? 'Tap to add image' : 'Medicine Image',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildEditableFields() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Count field
          _buildCountField(),
          const SizedBox(height: 16),

          // Packaging type field
          _buildPackagingField(),
          const SizedBox(height: 16),

          // MRP and PP fields
          Row(
            children: [
              Expanded(child: _buildMRPField()),
              const SizedBox(width: 16),
              Expanded(child: _buildPPField()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountField() {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            'Count:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              IconButton(
                onPressed: _isEditing ? () => _decrementCount() : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: _isEditing ? Colors.red : Colors.grey,
                iconSize: 24,
              ),
              Expanded(
                child: TextFormField(
                  controller: _countController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  enabled: _isEditing,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isEditing ? () => _incrementCount() : null,
                icon: const Icon(Icons.add_circle_outline),
                color: _isEditing ? Colors.green : Colors.grey,
                iconSize: 24,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPackagingField() {
    final packagingTypes = ['Packs', 'Bottles', 'Boxes', 'Strips', 'Pieces'];

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            'Packaging:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedPackagingType,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              filled: true,
              fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
            ),
            items:
                packagingTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
            onChanged:
                _isEditing
                    ? (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedPackagingType = newValue;
                          _hasUnsavedChanges = true;
                        });
                      }
                    }
                    : null,
          ),
        ),
      ],
    );
  }

  Widget _buildMRPField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MRP (₹):',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _mrpController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          enabled: _isEditing,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            filled: true,
            fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
            prefixText: '₹',
          ),
        ),
      ],
    );
  }

  Widget _buildPPField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PP (₹):',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _ppController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          enabled: _isEditing,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            filled: true,
            fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
            prefixText: '₹',
          ),
        ),
      ],
    );
  }

  Widget _buildSubTotalSection() {
    final subTotal = _calculateSubTotal();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.only(
          bottomLeft: const Radius.circular(12),
          bottomRight: const Radius.circular(12),
          topLeft:
              _isEditing && _hasUnsavedChanges
                  ? Radius.zero
                  : const Radius.circular(12),
          topRight:
              _isEditing && _hasUnsavedChanges
                  ? Radius.zero
                  : const Radius.circular(12),
        ),
        border: Border(top: BorderSide(color: Colors.blue.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Sub Total:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            '₹${subTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _discardChanges,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Discard Changes'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for handling field changes
  void _incrementCount() {
    final currentCount = int.tryParse(_countController.text) ?? 0;
    _countController.text = (currentCount + 1).toString();
    _onCountChanged();
  }

  void _decrementCount() {
    final currentCount = int.tryParse(_countController.text) ?? 0;
    if (currentCount > 0) {
      _countController.text = (currentCount - 1).toString();
      _onCountChanged();
    }
  }

  void _saveChanges() {
    if (!_validateInputs()) return;

    final updatedProduct = _currentProduct.copyWith(
      packagingType: _selectedPackagingType,
      imagePath: _selectedImagePath,
      lastUpdated: DateTime.now(),
      version: _currentProduct.version + 1,
    );

    widget.onProductSaved(updatedProduct);

    setState(() {
      _hasUnsavedChanges = false;
      _isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Changes saved successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _discardChanges() {
    setState(() {
          _currentProduct = widget.product;
      _countController.text = widget.product.count.toString();
      _mrpController.text = widget.product.mrp.toStringAsFixed(2);
      _ppController.text = widget.product.pp.toStringAsFixed(2);
      _selectedPackagingType = widget.product.packagingType;
      _selectedImagePath = widget.product.imagePath;
      _hasUnsavedChanges = false;
      _isEditing = false;
    });

      _notifyParentOfSubtotalChange();

  }

  bool _validateInputs() {
    final count = int.tryParse(_countController.text);
    final mrp = double.tryParse(_mrpController.text);
    final pp = double.tryParse(_ppController.text);

    if (count == null || count < 0) {
      _showValidationError('Count must be a valid positive number');
      return false;
    }

    if (mrp == null || mrp < 0) {
      _showValidationError('MRP must be a valid positive number');
      return false;
    }

    if (pp == null || pp < 0) {
      _showValidationError('PP must be a valid positive number');
      return false;
    }

    if (pp > mrp) {
      _showValidationError('Purchase Price cannot be higher than MRP');
      return false;
    }

    return true;
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  double _calculateSubTotal() {
    return _currentProduct.count * _currentProduct.pp;
  }

  void _showDeleteConfirmation() {
    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text(
            'Are you sure you want to delete "${widget.product.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                widget.onProductDeleted(widget.product.id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showDiscardChangesDialog() {
    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Discard Changes?'),
          content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep Editing'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                _discardChanges();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/product.dart';

/// Enhanced ProductCard widget with improved UI and sync indicators
/// Displays product information with editable fields and change tracking
class ProductCard extends StatefulWidget {
  final Product product;
  final Function(Product, String, dynamic, dynamic) onProductChanged;
  final Function(int) onProductDeleted;

  const ProductCard({
    super.key,
    required this.product,
    required this.onProductChanged,
    required this.onProductDeleted,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late TextEditingController _countController;
  late TextEditingController _mrpController;
  late TextEditingController _ppController;
  late String _selectedPackagingType;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _countController = TextEditingController(text: widget.product.count.toString());
    _mrpController = TextEditingController(text: widget.product.mrp.toStringAsFixed(2));
    _ppController = TextEditingController(text: widget.product.pp.toStringAsFixed(2));
    _selectedPackagingType = widget.product.packagingType;
  }

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
      ),
      child: Column(
        children: [
          // Header with product name and sync status
          _buildHeader(),
          
          // Product image
          _buildProductImage(),
          
          // Editable fields
          _buildEditableFields(),
          
          // Sub total section
          _buildSubTotalSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
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
                Text(
                  widget.product.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Updated by: ${widget.product.updatedBy} • v${widget.product.version}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          _buildSyncStatusBadge(),
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
    return Container(
      height: 120,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: widget.product.imagePath.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.product.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildImagePlaceholder();
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              ),
            )
          : _buildImagePlaceholder(),
    );
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
          Icon(
            Icons.medical_services,
            size: 40,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'Medicine Image',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
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
                onPressed: () => _decrementCount(),
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.red,
                iconSize: 24,
              ),
              Expanded(
                child: TextFormField(
                  controller: _countController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) => _onCountChanged(value),
                ),
              ),
              IconButton(
                onPressed: () => _incrementCount(),
                icon: const Icon(Icons.add_circle_outline),
                color: Colors.green,
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
              fillColor: Colors.grey.shade50,
            ),
            items: packagingTypes.map((String type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                _onPackagingChanged(newValue);
              }
            },
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
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixText: '₹',
          ),
          onChanged: (value) => _onMRPChanged(value),
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
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixText: '₹',
          ),
          onChanged: (value) => _onPPChanged(value),
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
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(color: Colors.blue.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Sub Total:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
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

  // Helper methods for handling field changes
  void _incrementCount() {
    final currentCount = int.tryParse(_countController.text) ?? 0;
    _countController.text = (currentCount + 1).toString();
    _onCountChanged(_countController.text);
  }

  void _decrementCount() {
    final currentCount = int.tryParse(_countController.text) ?? 0;
    if (currentCount > 0) {
      _countController.text = (currentCount - 1).toString();
      _onCountChanged(_countController.text);
    }
  }

  void _onCountChanged(String value) {
    final newCount = int.tryParse(value) ?? widget.product.count;
    final updatedProduct = widget.product.copyWith(count: newCount);
    widget.onProductChanged(updatedProduct, 'count', widget.product.count, newCount);
  }

  void _onPackagingChanged(String newPackaging) {
    setState(() {
      _selectedPackagingType = newPackaging;
    });
    final updatedProduct = widget.product.copyWith(packagingType: newPackaging);
    widget.onProductChanged(updatedProduct, 'packagingType', widget.product.packagingType, newPackaging);
  }

  void _onMRPChanged(String value) {
    final newMRP = double.tryParse(value) ?? widget.product.mrp;
    final updatedProduct = widget.product.copyWith(mrp: newMRP);
    widget.onProductChanged(updatedProduct, 'mrp', widget.product.mrp, newMRP);
  }

  void _onPPChanged(String value) {
    final newPP = double.tryParse(value) ?? widget.product.pp;
    final updatedProduct = widget.product.copyWith(pp: newPP);
    widget.onProductChanged(updatedProduct, 'pp', widget.product.pp, newPP);
  }

  double _calculateSubTotal() {
    final count = int.tryParse(_countController.text) ?? widget.product.count;
    final pp = double.tryParse(_ppController.text) ?? widget.product.pp;
    return count * pp;
  }

  void _showDeleteConfirmation() {
    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text(
            'Are you sure you want to delete "${widget.product.name}"?'
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
}
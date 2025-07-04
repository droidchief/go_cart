import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_cart/data/models/product.dart';
import 'package:go_cart/presentation/bloc/product_bloc.dart';
import 'package:go_cart/presentation/bloc/product_event.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';


class ProductCard extends StatefulWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late final TextEditingController _mrpController;
  late final TextEditingController _ppController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _mrpController = TextEditingController(text: widget.product.mrp.toStringAsFixed(2));
    _ppController = TextEditingController(text: widget.product.pp.toStringAsFixed(2));
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers only if the underlying product data has changed from the BLoC
    if (widget.product.mrp != oldWidget.product.mrp) {
      _mrpController.text = widget.product.mrp.toStringAsFixed(2);
    }
    if (widget.product.pp != oldWidget.product.pp) {
      _ppController.text = widget.product.pp.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _mrpController.dispose();
    _ppController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final directory = await getApplicationDocumentsDirectory();
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
      final String newPath = '${directory.path}/$fileName';
      await image.saveTo(newPath);
      
      // ignore: use_build_context_synchronously
      context.read<ProductBloc>().add(ProductLocalUpdateRequested(
        widget.product.copyWith(imagePath: newPath)
      ));
    }
  }

  Widget _buildImage(String path) {
    bool isNetwork = path.startsWith('http');
    return isNetwork
        ? Image.network(path, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 80, height: 80, color: Colors.grey[300], child: Icon(Icons.error)))
        : Image.file(File(path), width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 80, height: 80, color: Colors.grey[300], child: Icon(Icons.error)));
  }

  @override
  Widget build(BuildContext context) {
    final subTotal = widget.product.pp * widget.product.count;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: _buildImage(widget.product.imagePath),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Sub Total: \$${subTotal.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildCounter(context), _buildPackagingDropdown(context)]),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPriceField(context, 'MRP', _mrpController, (value) => context.read<ProductBloc>().add(ProductLocalUpdateRequested(widget.product.copyWith(mrp: double.tryParse(value) ?? widget.product.mrp)))),
                      const SizedBox(width: 10),
                      _buildPriceField(context, 'PP', _ppController, (value) => context.read<ProductBloc>().add(ProductLocalUpdateRequested(widget.product.copyWith(pp: double.tryParse(value) ?? widget.product.pp)))),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounter(BuildContext context) {
    return Row(children: [
      IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => widget.product.count > 1 ? context.read<ProductBloc>().add(ProductLocalUpdateRequested(widget.product.copyWith(count: widget.product.count - 1))) : null, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      Text(widget.product.count.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 16)),
      IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => context.read<ProductBloc>().add(ProductLocalUpdateRequested(widget.product.copyWith(count: widget.product.count + 1))), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
    ]);
  }

  Widget _buildPackagingDropdown(BuildContext context) {
    return DropdownButton<String>(
      value: widget.product.packagingType,
      items: ['Pcs', 'Packs', 'Box'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
      onChanged: (newValue) => newValue != null ? context.read<ProductBloc>().add(ProductLocalUpdateRequested(widget.product.copyWith(packagingType: newValue))) : null,
      underline: Container(),
    );
  }

  Widget _buildPriceField(BuildContext context, String label, TextEditingController controller, Function(String) onLostFocus) {
    return Expanded(
      child: Focus(
        onFocusChange: (hasFocus) => !hasFocus ? onLostFocus(controller.text) : null,
        child: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: label, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixText: '\$ ')),
      ),
    );
  }
}
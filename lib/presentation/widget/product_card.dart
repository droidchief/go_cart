import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_cart/data/models/product.dart';
import 'package:go_cart/presentation/bloc/product_bloc.dart';
import 'package:go_cart/presentation/bloc/product_event.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final subTotal = product.pp * product.count;
    final mrpController = TextEditingController(text: product.mrp.toStringAsFixed(2));
    final ppController = TextEditingController(text: product.pp.toStringAsFixed(2));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                product.imagePath,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => 
                  Container(width: 80, height: 80, color: Colors.grey[300], child: Icon(Icons.error)),
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Sub Total: \$${subTotal.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCounter(context),
                      _buildPackagingDropdown(context),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPriceField(context, 'MRP', mrpController, (value) {
                         final newMrp = double.tryParse(value) ?? product.mrp;
                         context.read<ProductBloc>().add(ProductLocalUpdateRequested(product.copyWith(mrp: newMrp)));
                      }),
                      const SizedBox(width: 10),
                      _buildPriceField(context, 'PP', ppController, (value) {
                         final newPp = double.tryParse(value) ?? product.pp;
                         context.read<ProductBloc>().add(ProductLocalUpdateRequested(product.copyWith(pp: newPp)));
                      }),
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
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () {
            if (product.count > 1) {
              context.read<ProductBloc>().add(ProductLocalUpdateRequested(product.copyWith(count: product.count - 1)));
            }
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        Text(product.count.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 16)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () {
            context.read<ProductBloc>().add(ProductLocalUpdateRequested(product.copyWith(count: product.count + 1)));
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildPackagingDropdown(BuildContext context) {
    return DropdownButton<String>(
      value: product.packagingType,
      items: ['Pcs', 'Packs', 'Box'].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (newValue) {
        if (newValue != null) {
          context.read<ProductBloc>().add(ProductLocalUpdateRequested(product.copyWith(packagingType: newValue)));
        }
      },
      underline: Container(), // Hides the default underline
    );
  }

  Widget _buildPriceField(BuildContext context, String label, TextEditingController controller, Function(String) onLostFocus) {
    return Expanded(
      child: Focus(
        onFocusChange: (hasFocus) {
            if(!hasFocus) {
                onLostFocus(controller.text);
            }
        },
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixText: '\$ '
          ),
        ),
      ),
    );
  }
}
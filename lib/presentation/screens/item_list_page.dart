import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_cart/presentation/bloc/product_bloc.dart';
import 'package:go_cart/presentation/bloc/product_event.dart';
import 'package:go_cart/presentation/bloc/product_state.dart';
import 'package:go_cart/presentation/widget/product_card.dart';

class ItemListPage extends StatelessWidget {
  final String appName;
  const ItemListPage({super.key, required this.appName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<ProductBloc, ProductState>(
          builder: (context, state) {
            final onlineStatus = state.isOnline ? 'Online' : 'Offline';
            final statusColor = state.isOnline ? Colors.green : Colors.red;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Item list ($appName)'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(onlineStatus, style: TextStyle(color: Colors.white, fontSize: 14)),
                )
              ],
            );
          },
        ),
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          if (state is ProductsLoadInProgress) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ProductsLoadSuccess) {
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: state.products.length,
              itemBuilder: (context, index) {
                return ProductCard(product: state.products[index]);
              },
            );
          }
          if (state is ProductsLoadFailure) {
            return Center(child: Text('Error: ${state.error}'));
          }
          return const Center(child: Text('Something went wrong.'));
        },
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        if (state is ProductsLoadSuccess) {
          final total = state.products.fold<double>(
              0.0, (sum, item) => sum + (item.pp * item.count));
          return Container(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 30),
            decoration: BoxDecoration(
              color: Colors.blue.shade800,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL: \$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: () {
                    context.read<ProductBloc>().add(SaveChangesRequested());
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.isOnline ? 'Changes saved to Common DB.' : 'Offline. Changes saved locally.'),
                        backgroundColor: state.isOnline ? Colors.green : Colors.orange,
                      )
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue.shade800,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

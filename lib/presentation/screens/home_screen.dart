import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_cart/data/models/product.dart';
import 'package:go_cart/presentation/widget/product_card.dart';
import 'package:go_cart/presentation/widget/sync_status_indicator.dart';
import 'package:go_cart/presentation/widget/total_section.dart';
import '../bloc/product_bloc.dart';
import '../bloc/product_event.dart';
import '../bloc/product_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Product> _currentProducts = [];
    List<Product> _liveProducts = []; 
  bool _hasPendingChanges = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<ProductBloc>().add(const LoadProducts());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('HOME_SCREEN: App resumed, forcing refresh...');

      // First reload local data
      context.read<ProductBloc>().add(const LoadProducts());

      // Then sync with shared database after a delay
      Timer(const Duration(seconds: 1), () {
        context.read<ProductBloc>().add(
          const SyncWithSharedDatabase(isManualSync: false),
        );
      });
    }
  }

    void _onProductSubtotalChanged(Product updatedProduct) {
    setState(() {
      final index = _liveProducts.indexWhere((p) => p.id == updatedProduct.id);
      if (index != -1) {
        _liveProducts[index] = updatedProduct;
      }
    });
  }

  // Calculate live total from _liveProducts
  double _calculateLiveTotal() {
    return _liveProducts.fold(0.0, (sum, product) => sum + (product.count * product.pp));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<ProductBloc, ProductState>(
          builder: (context, state) {
            final instanceId = context.read<ProductBloc>().instanceId;
            return Text('GOCart - ${instanceId.toUpperCase()}');
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () {
                context.read<ProductBloc>().add(const PrintDebugLogs());
              },
              tooltip: 'Print Debug Logs',
            ),
          const SyncStatusIndicator(),
       
        ],
      ),
      body: BlocConsumer<ProductBloc, ProductState>(
        listener: (context, state) {
          if (state is ProductError) {
            _showErrorSnackBar(context, state);
          } else if (state is ProductSaveSuccess) {
            _showSuccessSnackBar(
              context,
              'Data saved and synced to shared file',
            );
          } else if (state is ProductSyncSuccess) {
            _showSuccessSnackBar(context, 'Sync completed successfully');
          }

          // Update both current and live products
          if (state is ProductLoadSuccess) {
            _currentProducts = state.products;
            _liveProducts = List.from(state.products); 
            _hasPendingChanges = state.hasPendingChanges;
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              _buildStatusBar(state),

              Expanded(child: _buildProductList(state)),

              _buildTotalSection(state),

            ],
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildStatusBar(ProductState state) {
    Color backgroundColor;
    String statusText;
    IconData statusIcon;

    if (state is ProductLoading) {
      backgroundColor = Colors.orange.shade100;
      statusText = state.message;
      statusIcon = Icons.hourglass_empty;
    } else if (state is ProductSaving) {
      backgroundColor = Colors.blue.shade100;
      statusText = state.operation;
      statusIcon = Icons.save;
    } else if (state is ProductSyncing) {
      backgroundColor = Colors.purple.shade100;
      statusText = state.operation;
      statusIcon = Icons.sync;
    } else if (state is ProductError) {
      backgroundColor = Colors.red.shade100;
      statusText = state.message;
      statusIcon = Icons.error;
    } else if (state is ProductLoadSuccess && state.hasPendingChanges) {
      backgroundColor = Colors.yellow.shade100;
      statusText = 'You have unsaved changes';
      statusIcon = Icons.edit;
    } else if (state is ProductLoadSuccess) {
      backgroundColor = Colors.green.shade100;
      statusText =
          'All changes saved • Last updated: ${_formatTime(state.lastUpdated)}';
      statusIcon = Icons.check_circle;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: backgroundColor,
      child: Row(
        children: [
          Icon(statusIcon, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(statusText, style: const TextStyle(fontSize: 12)),
          ),
          if (state is ProductSyncing ||
              state is ProductSaving ||
              state is ProductLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildProductList(ProductState state) {
    if (state is ProductLoading && _currentProducts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading products...'),
          ],
        ),
      );
    }

    if (state is ProductError && _currentProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              state.message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<ProductBloc>().add(const LoadProducts());
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_currentProducts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No products available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _currentProducts.length,
      itemBuilder: (context, index) {
        final product = _currentProducts[index];
        return ProductCard(
          product: product,
          onProductSaved: (updatedProduct) {
            context.read<ProductBloc>().add(
              SaveProduct(product: updatedProduct),
            );
          },
          onProductDeleted: (productId) {
            context.read<ProductBloc>().add(
              DeleteProduct(productId: productId, reason: 'User deletion'),
            );
          },
          onSubtotalChanged: _onProductSubtotalChanged, 

        );
      },
    );
  }

  Widget _buildTotalSection(ProductState state) {
     final liveTotal = _calculateLiveTotal();
    final itemCount = _liveProducts.length;

    return TotalSection(
      totalAmount: liveTotal,
      itemCount: itemCount,
    );
  }


Widget? _buildFloatingActionButton() {
  return Padding(
    padding: const EdgeInsets.only(bottom: 80), 
    child: FloatingActionButton(
      onPressed: () {
        context.read<ProductBloc>().add(
          const SyncWithSharedDatabase(isManualSync: true),
        );
      },
      tooltip: 'Manual Sync',
      child: const Icon(Icons.refresh),
    ),
  );
}

 
  void _showErrorSnackBar(BuildContext context, ProductError state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(state.message),
        backgroundColor: Colors.red,
        action:
            state.isRecoverable
                ? SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    context.read<ProductBloc>().add(const LoadProducts());
                  },
                )
                : null,
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

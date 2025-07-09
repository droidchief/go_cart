import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_cart/data/models/product.dart';
import 'package:go_cart/presentation/widget/product_card.dart';
import 'package:go_cart/presentation/widget/sync_status_indicator.dart';
import 'package:go_cart/presentation/widget/total_section.dart';
import '../bloc/product_bloc.dart';
import '../bloc/product_event.dart';
import '../bloc/product_state.dart';

/// Enhanced Home Screen with sync indicators and improved UI
/// Shows product list, sync status, and total calculations
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Product> _currentProducts = [];
  bool _hasPendingChanges = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Load products when screen initializes
    context.read<ProductBloc>().add(const LoadProducts());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes for sync
    if (state == AppLifecycleState.resumed) {
      // App came to foreground, check for updates
      context.read<ProductBloc>().add(const SyncWithSharedDatabase(isManualSync: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<ProductBloc, ProductState>(
          builder: (context, state) {
            final instanceId = context.read<ProductBloc>().instanceId;
            return Text('Go Cart - ${instanceId.toUpperCase()}');
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Sync status indicator
          const SyncStatusIndicator(),
          // Manual sync button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ProductBloc>().add(
                const SyncWithSharedDatabase(isManualSync: true),
              );
            },
            tooltip: 'Manual Sync',
          ),
        ],
      ),
      body: BlocConsumer<ProductBloc, ProductState>(
        listener: (context, state) {
          // Handle state changes that need user feedback
          if (state is ProductError) {
            _showErrorSnackBar(context, state);
          } else if (state is ProductSaveSuccess) {
            _showSuccessSnackBar(context, 'Data saved and synced to shared file');
          } else if (state is ProductSyncSuccess) {
            _showSuccessSnackBar(context, 'Sync completed successfully');
          }
          
          // Update local state
          if (state is ProductLoadSuccess) {
            _currentProducts = state.products;
            _hasPendingChanges = state.hasPendingChanges;
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              // Status bar showing current state
              _buildStatusBar(state),
              
              // Product list
              Expanded(
                child: _buildProductList(state),
              ),
              
              // Total section
              _buildTotalSection(state),
              
              // Save button
              _buildSaveButton(state),
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
      statusText = 'All changes saved • Last updated: ${_formatTime(state.lastUpdated)}';
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
            child: Text(
              statusText,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (state is ProductSyncing || state is ProductSaving || state is ProductLoading)
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
          onProductChanged: (updatedProduct, fieldName, oldValue, newValue) {
            context.read<ProductBloc>().add(UpdateProduct(
              product: updatedProduct,
              fieldName: fieldName,
              oldValue: oldValue,
              newValue: newValue,
            ));
          },
          onProductDeleted: (productId) {
            context.read<ProductBloc>().add(DeleteProduct(
              productId: productId,
              reason: 'User deletion',
            ));
          },
        );
      },
    );
  }

  Widget _buildTotalSection(ProductState state) {
    double totalAmount = 0.0;
    
    if (state is ProductLoadSuccess) {
      totalAmount = state.totalAmount;
    } else if (_currentProducts.isNotEmpty) {
      totalAmount = ProductLoadSuccess.calculateTotal(_currentProducts);
    }

    return TotalSection(
      totalAmount: totalAmount,
      itemCount: _currentProducts.length,
    );
  }

  Widget _buildSaveButton(ProductState state) {
    final isLoading = state is ProductSaving || state is ProductSyncing;
    final hasChanges = _hasPendingChanges;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: (isLoading || !hasChanges) ? null : () {
          // Validate before saving
          context.read<ProductBloc>().add(ValidateProducts(
            products: _currentProducts,
          ));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: hasChanges ? Colors.blue : Colors.grey,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              isLoading ? 'Saving...' : (hasChanges ? 'Save Changes' : 'No Changes'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () {
        _showAddProductDialog();
      },
      tooltip: 'Add Product',
      child: const Icon(Icons.add),
    );
  }

  void _showAddProductDialog() {
    // This would show a dialog to add a new product
    // Implementation depends on your specific requirements
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Product'),
        content: const Text('Add product functionality would go here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Add new product logic
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, ProductError state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(state.message),
        backgroundColor: Colors.red,
        action: state.isRecoverable
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
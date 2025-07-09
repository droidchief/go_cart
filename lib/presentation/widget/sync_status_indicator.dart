import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/product_bloc.dart';
import '../bloc/product_state.dart';

/// Widget that shows the current sync status with visual indicators
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        return Container(
          margin: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSyncIcon(state),
              const SizedBox(width: 4),
              _buildSyncText(state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSyncIcon(ProductState state) {
    if (state is ProductSyncing) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.blue,
        ),
      );
    } else if (state is ProductLoadSuccess && state.hasPendingChanges) {
      return const Icon(
        Icons.sync_problem,
        size: 16,
        color: Colors.orange,
      );
    } else if (state is ProductError) {
      return const Icon(
        Icons.sync_disabled,
        size: 16,
        color: Colors.red,
      );
    } else if (state is ProductSyncSuccess || 
               (state is ProductLoadSuccess && !state.hasPendingChanges)) {
      return const Icon(
        Icons.sync,
        size: 16,
        color: Colors.green,
      );
    }
    
    return const Icon(
      Icons.sync,
      size: 16,
      color: Colors.grey,
    );
  }

  Widget _buildSyncText(ProductState state) {
    String text;
    Color color;
    
    if (state is ProductSyncing) {
      text = 'Syncing';
      color = Colors.blue;
    } else if (state is ProductLoadSuccess && state.hasPendingChanges) {
      text = 'Pending';
      color = Colors.orange;
    } else if (state is ProductError) {
      text = 'Error';
      color = Colors.red;
    } else if (state is ProductSyncSuccess || 
               (state is ProductLoadSuccess && !state.hasPendingChanges)) {
      text = 'Synced';
      color = Colors.green;
    } else {
      text = 'Ready';
      color = Colors.grey;
    }
    
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: color,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
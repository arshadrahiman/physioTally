import 'package:flutter_riverpod/flutter_riverpod.dart';

final billControllerProvider = NotifierProvider<BillController, BillState>(() {
  return BillController();
});

class BillState {
  final List<Map<String, String>> treatmentItems;
  final bool isLoading;

  const BillState({
    this.treatmentItems = const [],
    this.isLoading = false,
  });

  double get totalAmount {
    return treatmentItems.fold<double>(
      0.0,
      (sum, item) => sum + (double.tryParse(item['amount'] ?? '0') ?? 0.0),
    );
  }

  BillState copyWith({
    List<Map<String, String>>? treatmentItems,
    bool? isLoading,
  }) {
    return BillState(
      treatmentItems: treatmentItems ?? this.treatmentItems,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class BillController extends Notifier<BillState> {
  @override
  BillState build() {
    return const BillState(treatmentItems: []);
  }

  void addTreatment(Map<String, String> item) {
    state = state.copyWith(
      treatmentItems: [...state.treatmentItems, item],
    );
  }

  void removeTreatment(int index) {
    if (index >= 0 && index < state.treatmentItems.length) {
      final newList = List<Map<String, String>>.from(state.treatmentItems);
      newList.removeAt(index);
      state = state.copyWith(treatmentItems: newList);
    }
  }

  void clearTreatments() {
    state = state.copyWith(treatmentItems: const []);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }
}

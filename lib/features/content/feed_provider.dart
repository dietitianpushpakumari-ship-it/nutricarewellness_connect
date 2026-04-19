import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_shift/core/utils/feed_item_model.dart';
import 'package:pure_shift/core/utils/feed_repository.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';

// Assuming you have this provider from your previous setup

class FeedState {
  final List<FeedItemModel> items;
  final bool isLoading;
  final bool isFetchingMore;

  FeedState({this.items = const [], this.isLoading = false, this.isFetchingMore = false});
}

class FeedNotifier extends StateNotifier<FeedState> {
  final FeedRepository _repository;
  final String _tenantId; // 🚀 Require tenantId in the Notifier

  String _currentFilter = 'All';

  FeedNotifier(this._repository, this._tenantId) : super(FeedState()) {
    // Only attempt to load if we actually have a valid tenant ID
    if (_tenantId.isNotEmpty && _tenantId != 'guest') {
      refresh();
    } else {
      state = FeedState(items: [], isLoading: false);
    }
  }

  Future<void> refresh() async {
    if (_tenantId.isEmpty || _tenantId == 'guest') return;

    state = FeedState(items: [], isLoading: true);

    // 🔐 Pass tenantId to repository
    final items = await _repository.fetchFeed(
        _tenantId,
        filter: _currentFilter,
        isRefresh: true
    );

    state = FeedState(items: items, isLoading: false);
  }

  Future<void> loadMore() async {
    if (!_repository.hasMore || state.isFetchingMore || _tenantId.isEmpty || _tenantId == 'guest') return;

    state = FeedState(items: state.items, isLoading: false, isFetchingMore: true);

    // 🔐 Pass tenantId to repository
    final newItems = await _repository.fetchFeed(
        _tenantId,
        filter: _currentFilter
    );

    state = FeedState(
        items: [...state.items, ...newItems],
        isLoading: false,
        isFetchingMore: false
    );
  }

  void setFilter(String filter) {
    if (_currentFilter == filter) return;
    _currentFilter = filter;
    refresh();
  }

  bool get hasMore => _repository.hasMore;
}

// --- PROVIDERS ---

final feedRepositoryProvider = Provider((ref) => FeedRepository());

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  final repository = ref.watch(feedRepositoryProvider);

  // 🚀 THE FIX: Dynamically watch the active user's tenantId
  // (Make sure to import your currentTenantIdProvider or auth provider here)
  final tenantId = ref.watch(currentTenantIdProvider);

  return FeedNotifier(repository, tenantId);
});
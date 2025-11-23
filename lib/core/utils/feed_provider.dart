import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nutricare_connect/core/utils/feed_item_model.dart';
import 'package:nutricare_connect/core/utils/feed_repository.dart';


// The State Class
class FeedState {
  final List<FeedItemModel> items;
  final bool isLoading;
  final bool isFetchingMore;

  FeedState({this.items = const [], this.isLoading = false, this.isFetchingMore = false});
}

// The Notifier
class FeedNotifier extends StateNotifier<FeedState> {
  final FeedRepository _repository;
  String _currentFilter = 'All';

  FeedNotifier(this._repository) : super(FeedState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = FeedState(items: [], isLoading: true);
    final newItems = await _repository.fetchInitialFeed(filter: _currentFilter);
    state = FeedState(items: newItems, isLoading: false);
  }

  Future<void> refresh() async {
    // On refresh, we bypass cache implicitly by fetching page 1 from network
    final newItems = await _repository.fetchNextPage(filter: _currentFilter, isRefresh: true);
    state = FeedState(items: newItems, isLoading: false);
  }

  Future<void> loadMore() async {
    if (!_repository.hasMore || state.isFetchingMore) return;

    state = FeedState(items: state.items, isLoading: false, isFetchingMore: true);
    final moreItems = await _repository.fetchNextPage(filter: _currentFilter);

    state = FeedState(
        items: [...state.items, ...moreItems],
        isLoading: false,
        isFetchingMore: false
    );
  }

  void setFilter(String filter) {
    if (_currentFilter == filter) return;
    _currentFilter = filter;
    loadInitial(); // Reload with new filter
  }

  bool get hasMore => _repository.hasMore;
}

// The Provider
final feedRepositoryProvider = Provider((ref) => FeedRepository());

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier(ref.watch(feedRepositoryProvider));
});
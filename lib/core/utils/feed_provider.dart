import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nutricare_connect/core/utils/feed_item_model.dart';
import 'package:nutricare_connect/core/utils/feed_repository.dart';

class FeedState {
  final List<FeedItemModel> items;
  final bool isLoading;
  final bool isFetchingMore;

  FeedState({this.items = const [], this.isLoading = false, this.isFetchingMore = false});
}

class FeedNotifier extends StateNotifier<FeedState> {
  final FeedRepository _repository;
  String _currentFilter = 'All';

  FeedNotifier(this._repository) : super(FeedState()) {
    refresh();
  }

  Future<void> refresh() async {
    state = FeedState(items: [], isLoading: true);
    final items = await _repository.fetchFeed(filter: _currentFilter, isRefresh: true);
    state = FeedState(items: items, isLoading: false);
  }

  Future<void> loadMore() async {
    if (!_repository.hasMore || state.isFetchingMore) return;

    state = FeedState(items: state.items, isLoading: false, isFetchingMore: true);
    final newItems = await _repository.fetchFeed(filter: _currentFilter);

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

final feedRepositoryProvider = Provider((ref) => FeedRepository());
final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier(ref.watch(feedRepositoryProvider));
});
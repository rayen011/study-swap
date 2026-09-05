import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/auction.dart';
import '../data/auction_repository.dart';
import 'auction_state.dart';

/// The room's list: every live auction, closing soonest first.
class AuctionListCubit extends Cubit<AuctionListState> {
  AuctionListCubit(this._repository) : super(const AuctionListInitial());

  final AuctionRepository _repository;
  StreamSubscription<List<Auction>>? _subscription;

  /// Safe to call again — the previous subscription is replaced.
  void watch() {
    emit(const AuctionListLoading());
    _subscription?.cancel();
    _subscription = _repository.watchLive().listen(
      (auctions) => emit(AuctionListLoaded(auctions)),
      onError: (Object error) => emit(AuctionListError(error.toString())),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

/// One auction, its bid history, and the one thing the client may ask for.
class AuctionDetailCubit extends Cubit<AuctionDetailState> {
  AuctionDetailCubit(this._repository, this._auctionId)
    : super(const AuctionDetailLoading());

  final AuctionRepository _repository;
  final String _auctionId;

  StreamSubscription<Auction?>? _auctionSubscription;
  StreamSubscription<List<Bid>>? _bidsSubscription;

  Auction? _auction;
  List<Bid> _bids = const [];

  /// Whether the auction stream has produced anything yet.
  ///
  /// Firestore emits a snapshot for a document that does not exist, so a null
  /// auction means two different things depending on this flag: before the
  /// first emission it means "still loading", after it means "gone".
  bool _auctionSeen = false;

  void watch() {
    _auctionSubscription?.cancel();
    _bidsSubscription?.cancel();

    _auctionSubscription = _repository.watchAuction(_auctionId).listen(
      (auction) {
        _auction = auction;
        _auctionSeen = true;
        _emitLoaded();
      },
      onError: (Object error) => emit(AuctionDetailError(error.toString())),
    );

    _bidsSubscription = _repository.watchBids(_auctionId).listen(
      (bids) {
        _bids = bids;
        _emitLoaded();
      },
      // Bid history failing is not worth losing the auction over — the
      // countdown and the bid button matter more than the list.
      onError: (Object _) => _emitLoaded(),
    );
  }

  /// Asks the server to place a bid.
  ///
  /// Every rule this could break is checked again server-side, so nothing is
  /// validated here beyond not firing twice: a client-side refusal that the
  /// server would have allowed is worse than a round trip.
  Future<void> placeBid(int amount) async {
    final current = state;
    if (current is! AuctionDetailLoaded || current.isBidding) return;

    emit(
      current.copyWith(isBidding: true, clearRefusal: true, clearLastBid: true),
    );

    try {
      final placed = await _repository.placeBid(
        auctionId: _auctionId,
        amount: amount,
      );

      _emitLoaded(
        isBidding: false,
        lastBid: BidOutcome(
          amount: placed.amount,
          stakeLocked: placed.stakeLocked,
          extended: placed.extended,
        ),
      );
    } on BidRefused catch (refusal) {
      _emitLoaded(isBidding: false, refusal: refusal.message);
    } catch (_) {
      _emitLoaded(isBidding: false, refusal: 'That bid did not go through.');
    }
  }

  /// Clears a refusal once it has been shown, so it doesn't reappear when the
  /// auction stream ticks.
  void acknowledge() {
    final current = state;
    if (current is! AuctionDetailLoaded) return;
    emit(current.copyWith(clearRefusal: true, clearLastBid: true));
  }

  void _emitLoaded({bool? isBidding, String? refusal, BidOutcome? lastBid}) {
    final auction = _auction;

    if (auction == null) {
      if (_auctionSeen) emit(const AuctionDetailMissing());
      return;
    }

    final previous = state;
    emit(
      AuctionDetailLoaded(
        auction: auction,
        bids: _bids,
        isBidding:
            isBidding ??
            (previous is AuctionDetailLoaded && previous.isBidding),
        refusal:
            refusal ??
            (previous is AuctionDetailLoaded ? previous.refusal : null),
        lastBid:
            lastBid ??
            (previous is AuctionDetailLoaded ? previous.lastBid : null),
      ),
    );
  }

  @override
  Future<void> close() {
    _auctionSubscription?.cancel();
    _bidsSubscription?.cancel();
    return super.close();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/models/auction.dart';

/// Reads the auction floor, and asks to bid on it.
///
/// Note the asymmetry, which is the whole security model in one class: the
/// reads are ordinary Firestore streams, and the single write is a callable
/// function. `firestore.rules` denies the client every write on `auctions`,
/// so there is no `createAuction`, no `updateBid`, no `close` — a bid is a
/// *request*, and the server decides what happens to it.
class AuctionRepository {
  AuctionRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instanceFor(region: _region);

  /// Every function in this project lives in one region so they share a
  /// cold-start pool. Calling the default region instead fails with `not-found`.
  static const String _region = 'europe-west2';

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _auctions =>
      _firestore.collection('auctions');

  /// Live auctions, closing soonest first.
  ///
  /// The only ordering an auction list needs. Served by the composite index on
  /// `status` + `endsAt`, which the closer uses too.
  Stream<List<Auction>> watchLive({int limit = 30}) {
    return _auctions
        .where('status', isEqualTo: AuctionStatus.live.wire)
        .orderBy('endsAt')
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Auction.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<Auction?> watchAuction(String auctionId) {
    return _auctions.doc(auctionId).snapshots().map(Auction.fromDoc);
  }

  /// Bid history, newest first.
  Stream<List<Bid>> watchBids(String auctionId, {int limit = 25}) {
    return _auctions
        .doc(auctionId)
        .collection('bids')
        .orderBy('placedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => Bid.fromMap(doc.id, doc.data())).toList(),
        );
  }

  /// Asks the server to place a bid.
  ///
  /// Throws [BidRefused] when the server says no — which it does for good
  /// reasons the bidder needs to read, so the message is carried through
  /// rather than replaced with something generic.
  Future<BidPlaced> placeBid({
    required String auctionId,
    required int amount,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('placeBidCallable')
          .call<Map<String, dynamic>>({
            'auctionId': auctionId,
            'amount': amount,
          });

      final data = result.data;
      return BidPlaced(
        amount: (data['amount'] as num?)?.toInt() ?? amount,
        stakeLocked: (data['stakeLocked'] as num?)?.toInt() ?? 0,
        endsAt: DateTime.fromMillisecondsSinceEpoch(
          (data['endsAt'] as num?)?.toInt() ?? 0,
        ),
        extended: data['extended'] == true,
      );
    } on FirebaseFunctionsException catch (error) {
      throw BidRefused(_readable(error), code: error.code);
    }
  }

  /// Opens a floor on a listing you own.
  ///
  /// A callable, not a write: half of what an auction holds is not the
  /// seller's to set. A seller who could write `endsAt` could end the auction
  /// the moment the price suited them.
  ///
  /// [reservePrice] never reaches the auction document — the server files it
  /// where only the seller can read it.
  Future<String> createAuction({
    required String listingId,
    required int startPrice,
    required int durationHours,
    int? reservePrice,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('createAuctionCallable')
          .call<Map<String, dynamic>>({
            'listingId': listingId,
            'startPrice': startPrice,
            'durationHours': durationHours,
            'reservePrice': ?reservePrice,
          });

      return result.data['auctionId'] as String;
    } on FirebaseFunctionsException catch (error) {
      throw BidRefused(_readable(error), code: error.code);
    }
  }

  /// The server writes every refusal to be shown as-is — "The next bid has to
  /// be at least £105" tells a bidder what to do next in a way no code does.
  /// The fallbacks here are only for the failures that never reach the
  /// function at all.
  static String _readable(FirebaseFunctionsException error) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) return message;

    return switch (error.code) {
      'unauthenticated' => 'Sign in to bid.',
      'unavailable' || 'deadline-exceeded' =>
        'Could not reach the auction. Check your connection.',
      _ => 'That bid did not go through.',
    };
  }
}

/// What the server did with an accepted bid.
class BidPlaced {
  const BidPlaced({
    required this.amount,
    required this.stakeLocked,
    required this.endsAt,
    required this.extended,
  });

  final int amount;

  /// Credits now held against this bid.
  final int stakeLocked;

  /// The closing time as the server sees it, which may have just moved.
  final DateTime endsAt;

  /// True when this bid pushed the closing time out.
  final bool extended;
}

/// A bid the server refused, carrying a message written for the bidder.
class BidRefused implements Exception {
  const BidRefused(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

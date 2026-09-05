import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/core/constants/listing_options.dart';
import 'package:studyswap/core/models/app_user.dart';
import 'package:studyswap/core/models/chat_summary.dart';
import 'package:studyswap/core/models/listing.dart';
import 'package:studyswap/core/models/message.dart';
import 'package:studyswap/core/models/report.dart';
import 'package:studyswap/core/models/review.dart';

void main() {
  group('Listing.fromMap', () {
    test('reads a well-formed document', () {
      final listing = Listing.fromMap('abc', {
        'title': 'Campbell Biology 12th Ed',
        'description': 'Some highlighting in chapter 3.',
        'price': 24.5,
        'category': 'textbooks',
        'condition': 'good',
        'university': 'Oxford',
        'userId': 'seller-1',
        'sellerName': 'Amina',
        'imageUrl': '',
        'status': 'active',
      });

      expect(listing.id, 'abc');
      expect(listing.title, 'Campbell Biology 12th Ed');
      expect(listing.price, 24.5);
      expect(listing.category, ListingCategory.textbooks);
      expect(listing.condition, ListingCondition.good);
      expect(listing.status, ListingStatus.active);
      expect(listing.formattedPrice, '£24.50');
    });

    test('survives a document written by an older build', () {
      // Legacy casing, an int price, and no status field at all.
      final listing = Listing.fromMap('legacy', {
        'title': 'Old listing',
        'price': 30,
        'category': 'TEXTBOOKS',
        'condition': 'Like New',
      });

      expect(listing.category, ListingCategory.textbooks);
      expect(listing.condition, ListingCondition.likeNew);
      expect(listing.price, 30.0);
      expect(listing.status, ListingStatus.active);
      expect(listing.sellerName, 'Student');
    });

    test('degrades gracefully on an empty document', () {
      final listing = Listing.fromMap('empty', const {});

      expect(listing.title, 'Untitled listing');
      expect(listing.price, 0);
      expect(listing.category, isNull);
      expect(listing.categoryLabel, 'Other');
      expect(listing.conditionLabel, '');
      expect(listing.status, ListingStatus.active);
    });

    test('reads a multi-image listing in order', () {
      final listing = Listing.fromMap('x', {
        'imageUrls': ['https://a/0.jpg', 'https://a/1.jpg'],
      });

      expect(listing.hasImages, isTrue);
      expect(listing.imageUrls.length, 2);
      expect(listing.coverImageUrl, 'https://a/0.jpg');
    });

    test('falls back to the single imageUrl field on older listings', () {
      // Listings written before multi-image support carry one `imageUrl`.
      final listing = Listing.fromMap('legacy', {
        'imageUrl': 'https://a/cover.jpg',
      });

      expect(listing.imageUrls, ['https://a/cover.jpg']);
      expect(listing.coverImageUrl, 'https://a/cover.jpg');
    });

    test('treats an empty imageUrl as no photos', () {
      // Every listing created before this feature has `imageUrl: ''`, and a
      // blank string must not become a broken image widget.
      final listing = Listing.fromMap('x', {'imageUrl': ''});

      expect(listing.hasImages, isFalse);
      expect(listing.imageUrls, isEmpty);
      expect(listing.coverImageUrl, isNull);
    });

    test('drops blank entries from the image list', () {
      final listing = Listing.fromMap('x', {
        'imageUrls': ['', 'https://a/1.jpg', ''],
      });

      expect(listing.imageUrls, ['https://a/1.jpg']);
    });

    test('prefers imageUrls when a document carries both fields', () {
      final listing = Listing.fromMap('x', {
        'imageUrls': ['https://a/new.jpg'],
        'imageUrl': 'https://a/old.jpg',
      });

      expect(listing.imageUrls, ['https://a/new.jpg']);
    });

    test('isOwnedBy is false for a null uid', () {
      final listing = Listing.fromMap('x', {'userId': 'seller-1'});

      expect(listing.isOwnedBy('seller-1'), isTrue);
      expect(listing.isOwnedBy('someone-else'), isFalse);
      expect(listing.isOwnedBy(null), isFalse);
    });
  });

  group('ListingStatus', () {
    test('only active and reserved show in the public feed', () {
      expect(ListingStatus.active.isPubliclyVisible, isTrue);
      expect(ListingStatus.reserved.isPubliclyVisible, isTrue);
      expect(ListingStatus.sold.isPubliclyVisible, isFalse);
      expect(ListingStatus.hidden.isPubliclyVisible, isFalse);
    });

    test('only an active listing accepts deals', () {
      expect(ListingStatus.active.acceptsDeals, isTrue);
      expect(ListingStatus.reserved.acceptsDeals, isFalse);
      expect(ListingStatus.sold.acceptsDeals, isFalse);
    });
  });

  group('ListingDraft', () {
    test('writes wire values, not display labels', () {
      const draft = ListingDraft(
        title: 'Notes',
        description: '',
        price: 5,
        category: ListingCategory.studySummaries,
        condition: ListingCondition.likeNew,
        university: 'Oxford',
      );

      final map = draft.toMap();
      expect(map['category'], 'study_summaries');
      expect(map['condition'], 'like_new');
      expect(map['imageUrls'], isEmpty);
      // The repository owns these — a draft must not smuggle them in.
      expect(map.containsKey('userId'), isFalse);
      expect(map.containsKey('status'), isFalse);
    });

    test('withImageUrls carries every other field through', () {
      const draft = ListingDraft(
        title: 'Notes',
        description: 'Lecture notes',
        price: 5,
        category: ListingCategory.studySummaries,
        condition: ListingCondition.likeNew,
        university: 'Oxford',
      );

      final uploaded = draft.withImageUrls(['https://a/0.jpg']);

      expect(uploaded.imageUrls, ['https://a/0.jpg']);
      expect(uploaded.title, draft.title);
      expect(uploaded.description, draft.description);
      expect(uploaded.price, draft.price);
      expect(uploaded.category, draft.category);
      expect(uploaded.condition, draft.condition);
      expect(uploaded.university, draft.university);
    });
  });

  group('AppUser.fromMap', () {
    test('reads reputation fields', () {
      final user = AppUser.fromMap('u1', {
        'fullName': 'Amina Khan',
        'email': 'a@uni.ac.uk',
        'university': 'Oxford',
        'rating': 4.6666,
        'ratingCount': 3,
        'dealCount': 9,
        'title': 'Trade Regular',
      });

      expect(user.fullName, 'Amina Khan');
      expect(user.formattedRating, '4.7');
      expect(user.dealCount, 9);
      expect(user.hasUniversity, isTrue);
      expect(user.isSuspended, isFalse);
    });

    test('treats the placeholder university as absent', () {
      final user = AppUser.fromMap('u2', const {});

      expect(user.university, 'none');
      expect(user.hasUniversity, isFalse);
      expect(user.title, 'Freshman Trader');
      expect(user.formattedRating, '0.0');
    });

    test('reads the credit balance', () {
      final user = AppUser.fromMap('u1', const {
        'credits': 185,
        'creditsLocked': 60,
      });

      expect(user.credits, 185);
      expect(user.creditsLocked, 60);
      expect(user.availableCredits, 125);
      expect(user.maxBid, 1250);
    });

    test('an account from before credits existed reads as zero, not null', () {
      // Every profile written before this feature is missing both fields.
      final user = AppUser.fromMap('old', const {'fullName': 'Amina'});

      expect(user.credits, 0);
      expect(user.availableCredits, 0);
      expect(user.maxBid, 0);
    });

    test(
      'a balance behind its locked total shows nothing free, not a debt',
      () {
        final user = AppUser.fromMap('u3', const {
          'credits': 10,
          'creditsLocked': 40,
        });

        expect(user.availableCredits, 0);
        expect(user.maxBid, 0);
      },
    );
  });

  group('ChatSummary', () {
    ChatSummary build() => ChatSummary.fromMap('a_b', {
      'participants': ['a', 'b'],
      'participantNames': {'a': 'Amina', 'b': 'Ben'},
      'unreadCount': {'a': 0, 'b': 3},
      'lastMessage': 'Still available?',
      'lastSenderId': 'a',
    });

    test('resolves the other participant from either side', () {
      final chat = build();

      expect(chat.otherParticipantId('a'), 'b');
      expect(chat.otherParticipantName('a'), 'Ben');
      expect(chat.otherParticipantId('b'), 'a');
      expect(chat.otherParticipantName('b'), 'Amina');
    });

    test('reports unread counts per user', () {
      final chat = build();

      expect(chat.unreadFor('a'), 0);
      expect(chat.unreadFor('b'), 3);
      expect(chat.unreadFor('stranger'), 0);
    });

    test('falls back rather than throwing on a malformed chat', () {
      final chat = ChatSummary.fromMap('broken', const {});

      expect(chat.participants, isEmpty);
      expect(chat.otherParticipantId('a'), 'a');
      expect(chat.otherParticipantName('a'), 'Student');
      expect(chat.hasMessages, isFalse);
    });
  });

  group('Message', () {
    test('parses a plain text message', () {
      final msg = Message.fromMap('m1', {
        'senderId': 'a',
        'receiverId': 'b',
        'text': 'Still available?',
      });

      expect(msg.isDeal, isFalse);
      expect(msg.deal, isNull);
      expect(msg.isFrom('a'), isTrue);
      expect(msg.isFrom('b'), isFalse);
    });

    test('parses a deal message', () {
      final msg = Message.fromMap('m2', {
        'senderId': 'buyer',
        'receiverId': 'seller',
        'type': 'deal',
        'text': 'Deal Request for Notes',
        'dealData': {
          'itemId': 'listing-1',
          'title': 'Notes',
          'price': 12,
          'status': 'accepted',
          'buyerId': 'buyer',
          'sellerId': 'seller',
        },
      });

      expect(msg.isDeal, isTrue);
      expect(msg.deal!.status, DealStatus.accepted);
      expect(msg.deal!.formattedPrice, '£12.00');
      expect(msg.deal!.isSeller('seller'), isTrue);
      expect(msg.deal!.isBuyer('buyer'), isTrue);
    });

    test('falls back to listingOwnerId for older deal documents', () {
      // Early builds wrote the seller under both keys; some documents only
      // carry the old one.
      final deal = DealRequest.fromMap(const {
        'itemId': 'listing-1',
        'listingOwnerId': 'seller',
      });

      expect(deal.sellerId, 'seller');
      expect(deal.status, DealStatus.pending);
    });
  });

  group('Review', () {
    test('builds the deterministic id the rules enforce', () {
      expect(
        Review.idFor(chatId: 'a_b', fromId: 'a', toId: 'b'),
        'review_a_b_a_b',
      );
    });

    test('rounds the rating to a star count', () {
      Review at(double rating) =>
          Review.fromMap('r', {'rating': rating, 'comment': ''});

      expect(at(4.6).stars, 5);
      expect(at(4.4).stars, 4);
      expect(at(0).stars, 0);
      expect(at(9).stars, 5);
    });

    test('knows whether a comment was left', () {
      expect(Review.fromMap('r', {'comment': '  '}).hasComment, isFalse);
      expect(Review.fromMap('r', {'comment': 'Great'}).hasComment, isTrue);
    });
  });

  group('Report', () {
    test('parses target type and status', () {
      final report = Report.fromMap('r1', {
        'reporterId': 'a',
        'targetId': 'listing-1',
        'targetType': 'listing',
        'reason': 'Prohibited Item',
        'status': 'pending',
      });

      expect(report.targetType, ReportTargetType.listing);
      expect(report.targetType.isUser, isFalse);
      expect(report.status, ReportStatus.pending);
      expect(report.hasNote, isFalse);
    });

    test('defaults an unrecognised status to pending, not resolved', () {
      // A report must never silently drop out of the moderation queue.
      final report = Report.fromMap('r2', {'status': 'nonsense'});
      expect(report.status, ReportStatus.pending);
    });
  });
}

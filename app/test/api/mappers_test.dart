import 'package:backlog_manager/api/generated/export.dart';
import 'package:backlog_manager/api/mappers.dart';
import 'package:backlog_manager/domain/price_listings.dart' as price;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toNumber', () {
    test('parses decimal strings', () {
      expect(toNumber('12.5'), 12.5);
      expect(toNumber('4'), 4);
    });

    test('returns null for missing or unparsable values', () {
      expect(toNumber(null), isNull);
      expect(toNumber(''), isNull);
      expect(toNumber('abc'), isNull);
      expect(toNumber('NaN'), isNull);
      expect(toNumber('Infinity'), isNull);
    });
  });

  group('entryFromResponse', () {
    final response = BacklogEntryResponse(
      id: 7,
      title: 'Hades',
      genre: const ['Roguelike'],
      platform: const ['PC'],
      status: 'Playing',
      owned: true,
      interest: 4,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      mainTime: '21.5',
      playtime: '30',
      partnerPlaytime: 'oops',
      reviewStars: 9,
      steamAppId: 1145360,
    );

    test('maps the wire values to the app entry', () {
      final entry = entryFromResponse(response);

      expect(entry.id, 7);
      expect(entry.title, 'Hades');
      expect(entry.imageLink, '');
      expect(entry.imageAlt, 'Hades');
      expect(entry.mainTime, 21.5);
      expect(entry.playtime, 30);
      expect(entry.partnerPlaytime, isNull);
      expect(entry.reviewStars, 9);
      expect(entry.steamAppId, 1145360);
      expect(entry.inSharedSpace, isFalse);
    });
  });

  group('categoryFromResponse', () {
    test('keeps the description nullable', () {
      final category = categoryFromResponse(
        const CategoryResponse(id: 1, name: 'Co-op', color: '#38bdf8'),
      );

      expect(category.name, 'Co-op');
      expect(category.description, isNull);
    });
  });

  group('spaceFromResponse', () {
    test('maps the members and my status', () {
      final space = spaceFromResponse(
        const SpaceResponse(
          spaceId: 3,
          myStatus: 'active',
          members: [
            SpaceMemberResponse(username: 'me', status: 'active', isMe: true),
            SpaceMemberResponse(
              username: 'friend',
              status: 'invited',
              isMe: false,
            ),
          ],
        ),
      );

      expect(space.spaceId, 3);
      expect(space.myStatus, 'active');
      expect(space.members.map((m) => m.username), ['me', 'friend']);
      expect(space.members.first.isMe, isTrue);
    });
  });

  group('priceInfoFromResponse', () {
    final response = GamePrice(
      steamAppId: 1145360,
      onSale: true,
      checkedAt: DateTime.utc(2026),
      cheapestPriceEver: '9.99',
      deals: const [
        GamePriceDeal(
          store: 'Steam',
          icon: '/icons/steam.png',
          price: 12.5,
          retailPrice: 24.99,
          url: 'https://store.steampowered.com/app/1145360',
        ),
      ],
    );

    test('maps the deals and the all-time low', () {
      final info = priceInfoFromResponse(response);

      expect(info.onSale, isTrue);
      expect(info.cheapestPriceEver, 9.99);
      expect(info.deals.single.store, 'Steam');
      expect(info.deals.single.price, 12.5);
      expect(info.deals.single.retailPrice, 24.99);
    });

    test('has no all-time low when CheapShark knows none', () {
      final info = priceInfoFromResponse(
        GamePrice(
          steamAppId: 1,
          onSale: false,
          checkedAt: DateTime.utc(2026),
          deals: const [],
        ),
      );

      expect(info.cheapestPriceEver, isNull);
    });
  });

  test('keyShopOfferFromResponse maps an offer', () {
    final offer = keyShopOfferFromResponse(
      KeyShopOffer(
        shop: 'RoyalCDKeys',
        title: 'Hades',
        price: 9,
        currency: 'EUR',
        url: 'https://keys.example/hades',
        fetchedAt: DateTime.utc(2026),
        discountPct: 40,
      ),
    );

    expect(offer, isA<price.KeyShopOffer>());
    expect(offer.shop, 'RoyalCDKeys');
    expect(offer.price, 9);
    expect(offer.discountPct, 40);
  });

  test('achievementsFromResponse maps the progress and every achievement', () {
    final achievements = achievementsFromResponse(
      const AchievementProgress(
        unlocked: 1,
        total: 2,
        achievements: [
          AchievementInfo(
            apiname: 'ACH_1',
            displayName: 'First',
            description: 'Win once',
            icon: 'https://cdn.example/1.jpg',
            achieved: true,
            unlockTime: 1700000000,
            hidden: false,
          ),
          AchievementInfo(
            apiname: 'ACH_2',
            displayName: 'Secret',
            description: null,
            icon: null,
            achieved: false,
            unlockTime: 0,
            hidden: true,
          ),
        ],
      ),
    );

    expect(achievements.unlocked, 1);
    expect(achievements.total, 2);
    expect(achievements.items.map((a) => a.displayName), ['First', 'Secret']);
    expect(achievements.items.last.detail, 'Hidden achievement');
  });
}

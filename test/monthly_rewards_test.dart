import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/services/rewards_service.dart';

void main() {
  test('تقويم المكافأة: جائزة لكل يوم من أيام الشهر الحالي', () {
    final n = DateTime.now();
    final days = DateTime(n.year, n.month + 1, 0).day;
    final rewards = RewardsService.currentMonthRewards;
    expect(RewardsService.daysInCurrentMonth, days);
    expect(rewards.length, days);
    // الجائزة الكبرى في آخر يوم، وسكن كل 7 أيام، وجواهر في اليوم 5
    expect(rewards.last.type, RewardType.chips);
    expect(rewards.last.amount, 5000);
    expect(rewards[6].type, RewardType.skin);
    expect(rewards[4].type, RewardType.gems);
    expect(rewards.first.type, RewardType.chips);
  });
}

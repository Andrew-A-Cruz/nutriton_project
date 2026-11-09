import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/meal_slot.dart';
import 'package:nutriton_project/data/backup/backup_codec.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/schedule_repository.dart';

void main() {
  late AppDatabase db;
  late ScheduleRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ScheduleRepository(db);
    await db.mealDao.insertMeal(MealsCompanion.insert(id: 'm1', name: 'Lunch'));
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<String>> pendingOn(String date) async => [
    for (final p in await repo.watchPendingForDate(date).first) p.name,
  ];

  // 2026-11-09 is a Monday.
  test('a repeating plan stops after its end date', () async {
    await repo.scheduleWeekdays(
      mealId: 'm1',
      startDate: '2026-11-09',
      weekdays: {DateTime.monday},
      endDate: '2026-11-16',
    );
    expect(await pendingOn('2026-11-09'), ['Lunch']);
    expect(await pendingOn('2026-11-16'), ['Lunch']);
    expect(await pendingOn('2026-11-23'), isEmpty);
    await expectLater(
      repo.confirm(
        (await repo.watchPlans().first).single.schedule.id,
        date: '2026-11-23',
      ),
      throwsStateError,
    );
  });

  test('an end before the start is refused', () {
    expect(
      () => repo.scheduleWeekdays(
        mealId: 'm1',
        startDate: '2026-11-09',
        weekdays: {DateTime.monday},
        endDate: '2026-11-01',
      ),
      throwsArgumentError,
    );
  });

  test('editing changes days, slot, servings and end', () async {
    final id = await repo.scheduleWeekdays(
      mealId: 'm1',
      startDate: '2026-11-09',
      weekdays: {DateTime.monday},
    );
    await repo.updatePlan(
      id,
      startDate: '2026-11-09',
      weekdays: {DateTime.tuesday, DateTime.wednesday},
      mealSlot: MealSlot.dinner,
      servings: 2,
      endDate: '2026-11-30',
    );
    final plan = (await repo.watchPlans().first).single.schedule;
    expect(plan.weekdays, 0x06);
    expect(plan.mealSlot, 'dinner');
    expect(plan.servings, 2);
    expect(plan.endDate, '2026-11-30');
    expect(await pendingOn('2026-11-09'), isEmpty);
    expect(await pendingOn('2026-11-10'), ['Lunch']);

    // As a one-off it loses its end date.
    await repo.updatePlan(
      id,
      startDate: '2026-11-12',
      weekdays: null,
      mealSlot: null,
      servings: 1,
      endDate: '2026-11-30',
    );
    final once = (await repo.watchPlans().first).single.schedule;
    expect(once.weekdays, isNull);
    expect(once.endDate, isNull);
    expect(await pendingOn('2026-11-12'), ['Lunch']);
  });

  test('backups keep the end date and read older files without it', () async {
    await repo.scheduleWeekdays(
      mealId: 'm1',
      startDate: '2026-11-09',
      weekdays: {DateTime.monday},
      endDate: '2026-11-30',
    );
    final plan = (await repo.watchPlans().first).single.schedule;
    const codec = BackupCodec();
    final json =
        jsonDecode(
              codec.encode(
                BackupData(scheduledMeals: [plan], settings: UserSettings()),
              ),
            )
            as Map<String, dynamic>;
    final row = (json['scheduled_meals'] as List).single as Map;
    expect(row['endDate'], '2026-11-30');
    expect(
      codec.decode(jsonEncode(json)).scheduledMeals.single.endDate,
      '2026-11-30',
    );

    row.remove('endDate');
    expect(
      codec.decode(jsonEncode(json)).scheduledMeals.single.endDate,
      isNull,
    );
  });
}

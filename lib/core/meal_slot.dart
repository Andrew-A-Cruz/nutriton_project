/// The part of the day an entry belongs to. Stored by [name] in the nullable
/// `meal_slot` column; null means "Other".
enum MealSlot {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  snack('Snack');

  const MealSlot(this.label);

  final String label;

  /// The slot called [name], or null for null or an unknown name.
  static MealSlot? fromName(String? name) {
    if (name == null) return null;
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }

  /// Default slot by time of day: before 10:30 breakfast, before 15:00 lunch,
  /// before 20:00 dinner, otherwise snack.
  static MealSlot forTime(DateTime t) {
    final minutes = t.hour * 60 + t.minute;
    if (minutes < 10 * 60 + 30) return breakfast;
    if (minutes < 15 * 60) return lunch;
    if (minutes < 20 * 60) return dinner;
    return snack;
  }
}

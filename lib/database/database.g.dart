// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $FoodItemsTable extends FoodItems
    with TableInfo<$FoodItemsTable, FoodItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 2,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caloriesMeta = const VerificationMeta(
    'calories',
  );
  @override
  late final GeneratedColumn<double> calories = GeneratedColumn<double>(
    'calories',
    aliasedName,
    false,
    check: () => ComparableExpr(calories).isBiggerOrEqualValue(0),
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proteinMeta = const VerificationMeta(
    'protein',
  );
  @override
  late final GeneratedColumn<double> protein = GeneratedColumn<double>(
    'protein',
    aliasedName,
    false,
    check: () => ComparableExpr(protein).isBiggerOrEqualValue(0),
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carbsMeta = const VerificationMeta('carbs');
  @override
  late final GeneratedColumn<double> carbs = GeneratedColumn<double>(
    'carbs',
    aliasedName,
    false,
    check: () => ComparableExpr(carbs).isBiggerOrEqualValue(0),
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fatMeta = const VerificationMeta('fat');
  @override
  late final GeneratedColumn<double> fat = GeneratedColumn<double>(
    'fat',
    aliasedName,
    false,
    check: () => ComparableExpr(fat).isBiggerOrEqualValue(0),
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _servingWeightMeta = const VerificationMeta(
    'servingWeight',
  );
  @override
  late final GeneratedColumn<double> servingWeight = GeneratedColumn<double>(
    'serving_weight',
    aliasedName,
    false,
    check: () => ComparableExpr(servingWeight).isBiggerOrEqualValue(0),
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightUnitMeta = const VerificationMeta(
    'weightUnit',
  );
  @override
  late final GeneratedColumn<String> weightUnit = GeneratedColumn<String>(
    'weight_unit',
    aliasedName,
    false,
    check: () => weightUnit.isIn(['g', 'oz']),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    calories,
    protein,
    carbs,
    fat,
    servingWeight,
    weightUnit,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'food_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<FoodItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('calories')) {
      context.handle(
        _caloriesMeta,
        calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta),
      );
    } else if (isInserting) {
      context.missing(_caloriesMeta);
    }
    if (data.containsKey('protein')) {
      context.handle(
        _proteinMeta,
        protein.isAcceptableOrUnknown(data['protein']!, _proteinMeta),
      );
    } else if (isInserting) {
      context.missing(_proteinMeta);
    }
    if (data.containsKey('carbs')) {
      context.handle(
        _carbsMeta,
        carbs.isAcceptableOrUnknown(data['carbs']!, _carbsMeta),
      );
    } else if (isInserting) {
      context.missing(_carbsMeta);
    }
    if (data.containsKey('fat')) {
      context.handle(
        _fatMeta,
        fat.isAcceptableOrUnknown(data['fat']!, _fatMeta),
      );
    } else if (isInserting) {
      context.missing(_fatMeta);
    }
    if (data.containsKey('serving_weight')) {
      context.handle(
        _servingWeightMeta,
        servingWeight.isAcceptableOrUnknown(
          data['serving_weight']!,
          _servingWeightMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_servingWeightMeta);
    }
    if (data.containsKey('weight_unit')) {
      context.handle(
        _weightUnitMeta,
        weightUnit.isAcceptableOrUnknown(data['weight_unit']!, _weightUnitMeta),
      );
    } else if (isInserting) {
      context.missing(_weightUnitMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FoodItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      calories: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}calories'],
      )!,
      protein: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein'],
      )!,
      carbs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs'],
      )!,
      fat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fat'],
      )!,
      servingWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}serving_weight'],
      )!,
      weightUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weight_unit'],
      )!,
    );
  }

  @override
  $FoodItemsTable createAlias(String alias) {
    return $FoodItemsTable(attachedDatabase, alias);
  }
}

class FoodItem extends DataClass implements Insertable<FoodItem> {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double servingWeight;
  final String weightUnit;
  const FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingWeight,
    required this.weightUnit,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['calories'] = Variable<double>(calories);
    map['protein'] = Variable<double>(protein);
    map['carbs'] = Variable<double>(carbs);
    map['fat'] = Variable<double>(fat);
    map['serving_weight'] = Variable<double>(servingWeight);
    map['weight_unit'] = Variable<String>(weightUnit);
    return map;
  }

  FoodItemsCompanion toCompanion(bool nullToAbsent) {
    return FoodItemsCompanion(
      id: Value(id),
      name: Value(name),
      calories: Value(calories),
      protein: Value(protein),
      carbs: Value(carbs),
      fat: Value(fat),
      servingWeight: Value(servingWeight),
      weightUnit: Value(weightUnit),
    );
  }

  factory FoodItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodItem(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      calories: serializer.fromJson<double>(json['calories']),
      protein: serializer.fromJson<double>(json['protein']),
      carbs: serializer.fromJson<double>(json['carbs']),
      fat: serializer.fromJson<double>(json['fat']),
      servingWeight: serializer.fromJson<double>(json['servingWeight']),
      weightUnit: serializer.fromJson<String>(json['weightUnit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'calories': serializer.toJson<double>(calories),
      'protein': serializer.toJson<double>(protein),
      'carbs': serializer.toJson<double>(carbs),
      'fat': serializer.toJson<double>(fat),
      'servingWeight': serializer.toJson<double>(servingWeight),
      'weightUnit': serializer.toJson<String>(weightUnit),
    };
  }

  FoodItem copyWith({
    String? id,
    String? name,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? servingWeight,
    String? weightUnit,
  }) => FoodItem(
    id: id ?? this.id,
    name: name ?? this.name,
    calories: calories ?? this.calories,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
    servingWeight: servingWeight ?? this.servingWeight,
    weightUnit: weightUnit ?? this.weightUnit,
  );
  FoodItem copyWithCompanion(FoodItemsCompanion data) {
    return FoodItem(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      calories: data.calories.present ? data.calories.value : this.calories,
      protein: data.protein.present ? data.protein.value : this.protein,
      carbs: data.carbs.present ? data.carbs.value : this.carbs,
      fat: data.fat.present ? data.fat.value : this.fat,
      servingWeight: data.servingWeight.present
          ? data.servingWeight.value
          : this.servingWeight,
      weightUnit: data.weightUnit.present
          ? data.weightUnit.value
          : this.weightUnit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodItem(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fat: $fat, ')
          ..write('servingWeight: $servingWeight, ')
          ..write('weightUnit: $weightUnit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    calories,
    protein,
    carbs,
    fat,
    servingWeight,
    weightUnit,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodItem &&
          other.id == this.id &&
          other.name == this.name &&
          other.calories == this.calories &&
          other.protein == this.protein &&
          other.carbs == this.carbs &&
          other.fat == this.fat &&
          other.servingWeight == this.servingWeight &&
          other.weightUnit == this.weightUnit);
}

class FoodItemsCompanion extends UpdateCompanion<FoodItem> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> calories;
  final Value<double> protein;
  final Value<double> carbs;
  final Value<double> fat;
  final Value<double> servingWeight;
  final Value<String> weightUnit;
  final Value<int> rowid;
  const FoodItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.calories = const Value.absent(),
    this.protein = const Value.absent(),
    this.carbs = const Value.absent(),
    this.fat = const Value.absent(),
    this.servingWeight = const Value.absent(),
    this.weightUnit = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoodItemsCompanion.insert({
    required String id,
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double servingWeight,
    required String weightUnit,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       calories = Value(calories),
       protein = Value(protein),
       carbs = Value(carbs),
       fat = Value(fat),
       servingWeight = Value(servingWeight),
       weightUnit = Value(weightUnit);
  static Insertable<FoodItem> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? calories,
    Expression<double>? protein,
    Expression<double>? carbs,
    Expression<double>? fat,
    Expression<double>? servingWeight,
    Expression<String>? weightUnit,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein': protein,
      if (carbs != null) 'carbs': carbs,
      if (fat != null) 'fat': fat,
      if (servingWeight != null) 'serving_weight': servingWeight,
      if (weightUnit != null) 'weight_unit': weightUnit,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoodItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<double>? calories,
    Value<double>? protein,
    Value<double>? carbs,
    Value<double>? fat,
    Value<double>? servingWeight,
    Value<String>? weightUnit,
    Value<int>? rowid,
  }) {
    return FoodItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      servingWeight: servingWeight ?? this.servingWeight,
      weightUnit: weightUnit ?? this.weightUnit,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (calories.present) {
      map['calories'] = Variable<double>(calories.value);
    }
    if (protein.present) {
      map['protein'] = Variable<double>(protein.value);
    }
    if (carbs.present) {
      map['carbs'] = Variable<double>(carbs.value);
    }
    if (fat.present) {
      map['fat'] = Variable<double>(fat.value);
    }
    if (servingWeight.present) {
      map['serving_weight'] = Variable<double>(servingWeight.value);
    }
    if (weightUnit.present) {
      map['weight_unit'] = Variable<String>(weightUnit.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fat: $fat, ')
          ..write('servingWeight: $servingWeight, ')
          ..write('weightUnit: $weightUnit, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MealsTable extends Meals with TableInfo<$MealsTable, Meal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 2,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Meal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Meal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Meal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $MealsTable createAlias(String alias) {
    return $MealsTable(attachedDatabase, alias);
  }
}

class Meal extends DataClass implements Insertable<Meal> {
  final String id;
  final String name;
  const Meal({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  MealsCompanion toCompanion(bool nullToAbsent) {
    return MealsCompanion(id: Value(id), name: Value(name));
  }

  factory Meal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Meal(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Meal copyWith({String? id, String? name}) =>
      Meal(id: id ?? this.id, name: name ?? this.name);
  Meal copyWithCompanion(MealsCompanion data) {
    return Meal(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Meal(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Meal && other.id == this.id && other.name == this.name);
}

class MealsCompanion extends UpdateCompanion<Meal> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> rowid;
  const MealsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MealsCompanion.insert({
    required String id,
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Meal> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MealsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return MealsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MealFoodItemsTable extends MealFoodItems
    with TableInfo<$MealFoodItemsTable, MealFoodItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealFoodItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mealIdMeta = const VerificationMeta('mealId');
  @override
  late final GeneratedColumn<String> mealId = GeneratedColumn<String>(
    'meal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meals (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _foodItemIdMeta = const VerificationMeta(
    'foodItemId',
  );
  @override
  late final GeneratedColumn<String> foodItemId = GeneratedColumn<String>(
    'food_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES food_items (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _servingWeightMeta = const VerificationMeta(
    'servingWeight',
  );
  @override
  late final GeneratedColumn<double> servingWeight = GeneratedColumn<double>(
    'serving_weight',
    aliasedName,
    false,
    check: () => ComparableExpr(servingWeight).isBiggerOrEqualValue(0),
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightUnitMeta = const VerificationMeta(
    'weightUnit',
  );
  @override
  late final GeneratedColumn<String> weightUnit = GeneratedColumn<String>(
    'weight_unit',
    aliasedName,
    false,
    check: () => weightUnit.isIn(['g', 'oz']),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mealId,
    foodItemId,
    servingWeight,
    weightUnit,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_food_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealFoodItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('meal_id')) {
      context.handle(
        _mealIdMeta,
        mealId.isAcceptableOrUnknown(data['meal_id']!, _mealIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mealIdMeta);
    }
    if (data.containsKey('food_item_id')) {
      context.handle(
        _foodItemIdMeta,
        foodItemId.isAcceptableOrUnknown(
          data['food_item_id']!,
          _foodItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_foodItemIdMeta);
    }
    if (data.containsKey('serving_weight')) {
      context.handle(
        _servingWeightMeta,
        servingWeight.isAcceptableOrUnknown(
          data['serving_weight']!,
          _servingWeightMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_servingWeightMeta);
    }
    if (data.containsKey('weight_unit')) {
      context.handle(
        _weightUnitMeta,
        weightUnit.isAcceptableOrUnknown(data['weight_unit']!, _weightUnitMeta),
      );
    } else if (isInserting) {
      context.missing(_weightUnitMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealFoodItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealFoodItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mealId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_id'],
      )!,
      foodItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_item_id'],
      )!,
      servingWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}serving_weight'],
      )!,
      weightUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weight_unit'],
      )!,
    );
  }

  @override
  $MealFoodItemsTable createAlias(String alias) {
    return $MealFoodItemsTable(attachedDatabase, alias);
  }
}

class MealFoodItem extends DataClass implements Insertable<MealFoodItem> {
  final String id;
  final String mealId;
  final String foodItemId;
  final double servingWeight;
  final String weightUnit;
  const MealFoodItem({
    required this.id,
    required this.mealId,
    required this.foodItemId,
    required this.servingWeight,
    required this.weightUnit,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['meal_id'] = Variable<String>(mealId);
    map['food_item_id'] = Variable<String>(foodItemId);
    map['serving_weight'] = Variable<double>(servingWeight);
    map['weight_unit'] = Variable<String>(weightUnit);
    return map;
  }

  MealFoodItemsCompanion toCompanion(bool nullToAbsent) {
    return MealFoodItemsCompanion(
      id: Value(id),
      mealId: Value(mealId),
      foodItemId: Value(foodItemId),
      servingWeight: Value(servingWeight),
      weightUnit: Value(weightUnit),
    );
  }

  factory MealFoodItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealFoodItem(
      id: serializer.fromJson<String>(json['id']),
      mealId: serializer.fromJson<String>(json['mealId']),
      foodItemId: serializer.fromJson<String>(json['foodItemId']),
      servingWeight: serializer.fromJson<double>(json['servingWeight']),
      weightUnit: serializer.fromJson<String>(json['weightUnit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mealId': serializer.toJson<String>(mealId),
      'foodItemId': serializer.toJson<String>(foodItemId),
      'servingWeight': serializer.toJson<double>(servingWeight),
      'weightUnit': serializer.toJson<String>(weightUnit),
    };
  }

  MealFoodItem copyWith({
    String? id,
    String? mealId,
    String? foodItemId,
    double? servingWeight,
    String? weightUnit,
  }) => MealFoodItem(
    id: id ?? this.id,
    mealId: mealId ?? this.mealId,
    foodItemId: foodItemId ?? this.foodItemId,
    servingWeight: servingWeight ?? this.servingWeight,
    weightUnit: weightUnit ?? this.weightUnit,
  );
  MealFoodItem copyWithCompanion(MealFoodItemsCompanion data) {
    return MealFoodItem(
      id: data.id.present ? data.id.value : this.id,
      mealId: data.mealId.present ? data.mealId.value : this.mealId,
      foodItemId: data.foodItemId.present
          ? data.foodItemId.value
          : this.foodItemId,
      servingWeight: data.servingWeight.present
          ? data.servingWeight.value
          : this.servingWeight,
      weightUnit: data.weightUnit.present
          ? data.weightUnit.value
          : this.weightUnit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealFoodItem(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('foodItemId: $foodItemId, ')
          ..write('servingWeight: $servingWeight, ')
          ..write('weightUnit: $weightUnit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, mealId, foodItemId, servingWeight, weightUnit);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealFoodItem &&
          other.id == this.id &&
          other.mealId == this.mealId &&
          other.foodItemId == this.foodItemId &&
          other.servingWeight == this.servingWeight &&
          other.weightUnit == this.weightUnit);
}

class MealFoodItemsCompanion extends UpdateCompanion<MealFoodItem> {
  final Value<String> id;
  final Value<String> mealId;
  final Value<String> foodItemId;
  final Value<double> servingWeight;
  final Value<String> weightUnit;
  final Value<int> rowid;
  const MealFoodItemsCompanion({
    this.id = const Value.absent(),
    this.mealId = const Value.absent(),
    this.foodItemId = const Value.absent(),
    this.servingWeight = const Value.absent(),
    this.weightUnit = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MealFoodItemsCompanion.insert({
    required String id,
    required String mealId,
    required String foodItemId,
    required double servingWeight,
    required String weightUnit,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mealId = Value(mealId),
       foodItemId = Value(foodItemId),
       servingWeight = Value(servingWeight),
       weightUnit = Value(weightUnit);
  static Insertable<MealFoodItem> custom({
    Expression<String>? id,
    Expression<String>? mealId,
    Expression<String>? foodItemId,
    Expression<double>? servingWeight,
    Expression<String>? weightUnit,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mealId != null) 'meal_id': mealId,
      if (foodItemId != null) 'food_item_id': foodItemId,
      if (servingWeight != null) 'serving_weight': servingWeight,
      if (weightUnit != null) 'weight_unit': weightUnit,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MealFoodItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? mealId,
    Value<String>? foodItemId,
    Value<double>? servingWeight,
    Value<String>? weightUnit,
    Value<int>? rowid,
  }) {
    return MealFoodItemsCompanion(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      foodItemId: foodItemId ?? this.foodItemId,
      servingWeight: servingWeight ?? this.servingWeight,
      weightUnit: weightUnit ?? this.weightUnit,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mealId.present) {
      map['meal_id'] = Variable<String>(mealId.value);
    }
    if (foodItemId.present) {
      map['food_item_id'] = Variable<String>(foodItemId.value);
    }
    if (servingWeight.present) {
      map['serving_weight'] = Variable<double>(servingWeight.value);
    }
    if (weightUnit.present) {
      map['weight_unit'] = Variable<String>(weightUnit.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealFoodItemsCompanion(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('foodItemId: $foodItemId, ')
          ..write('servingWeight: $servingWeight, ')
          ..write('weightUnit: $weightUnit, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FoodLogEntriesTable extends FoodLogEntries
    with TableInfo<$FoodLogEntriesTable, FoodLogEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodLogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _logDateMeta = const VerificationMeta(
    'logDate',
  );
  @override
  late final GeneratedColumn<DateTime> logDate = GeneratedColumn<DateTime>(
    'log_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodItemIdMeta = const VerificationMeta(
    'foodItemId',
  );
  @override
  late final GeneratedColumn<String> foodItemId = GeneratedColumn<String>(
    'food_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES food_items (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _servingsMeta = const VerificationMeta(
    'servings',
  );
  @override
  late final GeneratedColumn<double> servings = GeneratedColumn<double>(
    'servings',
    aliasedName,
    true,
    check: () => ComparableExpr(servings).isBiggerOrEqualValue(0),
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mealIdMeta = const VerificationMeta('mealId');
  @override
  late final GeneratedColumn<String> mealId = GeneratedColumn<String>(
    'meal_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meals (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _adhocNameMeta = const VerificationMeta(
    'adhocName',
  );
  @override
  late final GeneratedColumn<String> adhocName = GeneratedColumn<String>(
    'adhoc_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _adhocCaloriesMeta = const VerificationMeta(
    'adhocCalories',
  );
  @override
  late final GeneratedColumn<double> adhocCalories = GeneratedColumn<double>(
    'adhoc_calories',
    aliasedName,
    true,
    check: () => ComparableExpr(adhocCalories).isBiggerOrEqualValue(0),
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _adhocProteinMeta = const VerificationMeta(
    'adhocProtein',
  );
  @override
  late final GeneratedColumn<double> adhocProtein = GeneratedColumn<double>(
    'adhoc_protein',
    aliasedName,
    true,
    check: () => ComparableExpr(adhocProtein).isBiggerOrEqualValue(0),
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _adhocCarbsMeta = const VerificationMeta(
    'adhocCarbs',
  );
  @override
  late final GeneratedColumn<double> adhocCarbs = GeneratedColumn<double>(
    'adhoc_carbs',
    aliasedName,
    true,
    check: () => ComparableExpr(adhocCarbs).isBiggerOrEqualValue(0),
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _adhocFatMeta = const VerificationMeta(
    'adhocFat',
  );
  @override
  late final GeneratedColumn<double> adhocFat = GeneratedColumn<double>(
    'adhoc_fat',
    aliasedName,
    true,
    check: () => ComparableExpr(adhocFat).isBiggerOrEqualValue(0),
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    logDate,
    foodItemId,
    servings,
    mealId,
    adhocName,
    adhocCalories,
    adhocProtein,
    adhocCarbs,
    adhocFat,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'food_log_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<FoodLogEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('log_date')) {
      context.handle(
        _logDateMeta,
        logDate.isAcceptableOrUnknown(data['log_date']!, _logDateMeta),
      );
    } else if (isInserting) {
      context.missing(_logDateMeta);
    }
    if (data.containsKey('food_item_id')) {
      context.handle(
        _foodItemIdMeta,
        foodItemId.isAcceptableOrUnknown(
          data['food_item_id']!,
          _foodItemIdMeta,
        ),
      );
    }
    if (data.containsKey('servings')) {
      context.handle(
        _servingsMeta,
        servings.isAcceptableOrUnknown(data['servings']!, _servingsMeta),
      );
    }
    if (data.containsKey('meal_id')) {
      context.handle(
        _mealIdMeta,
        mealId.isAcceptableOrUnknown(data['meal_id']!, _mealIdMeta),
      );
    }
    if (data.containsKey('adhoc_name')) {
      context.handle(
        _adhocNameMeta,
        adhocName.isAcceptableOrUnknown(data['adhoc_name']!, _adhocNameMeta),
      );
    }
    if (data.containsKey('adhoc_calories')) {
      context.handle(
        _adhocCaloriesMeta,
        adhocCalories.isAcceptableOrUnknown(
          data['adhoc_calories']!,
          _adhocCaloriesMeta,
        ),
      );
    }
    if (data.containsKey('adhoc_protein')) {
      context.handle(
        _adhocProteinMeta,
        adhocProtein.isAcceptableOrUnknown(
          data['adhoc_protein']!,
          _adhocProteinMeta,
        ),
      );
    }
    if (data.containsKey('adhoc_carbs')) {
      context.handle(
        _adhocCarbsMeta,
        adhocCarbs.isAcceptableOrUnknown(data['adhoc_carbs']!, _adhocCarbsMeta),
      );
    }
    if (data.containsKey('adhoc_fat')) {
      context.handle(
        _adhocFatMeta,
        adhocFat.isAcceptableOrUnknown(data['adhoc_fat']!, _adhocFatMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FoodLogEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodLogEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      logDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}log_date'],
      )!,
      foodItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_item_id'],
      ),
      servings: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}servings'],
      ),
      mealId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_id'],
      ),
      adhocName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}adhoc_name'],
      ),
      adhocCalories: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}adhoc_calories'],
      ),
      adhocProtein: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}adhoc_protein'],
      ),
      adhocCarbs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}adhoc_carbs'],
      ),
      adhocFat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}adhoc_fat'],
      ),
    );
  }

  @override
  $FoodLogEntriesTable createAlias(String alias) {
    return $FoodLogEntriesTable(attachedDatabase, alias);
  }
}

class FoodLogEntry extends DataClass implements Insertable<FoodLogEntry> {
  final String id;
  final DateTime logDate;
  final String? foodItemId;
  final double? servings;
  final String? mealId;
  final String? adhocName;
  final double? adhocCalories;
  final double? adhocProtein;
  final double? adhocCarbs;
  final double? adhocFat;
  const FoodLogEntry({
    required this.id,
    required this.logDate,
    this.foodItemId,
    this.servings,
    this.mealId,
    this.adhocName,
    this.adhocCalories,
    this.adhocProtein,
    this.adhocCarbs,
    this.adhocFat,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['log_date'] = Variable<DateTime>(logDate);
    if (!nullToAbsent || foodItemId != null) {
      map['food_item_id'] = Variable<String>(foodItemId);
    }
    if (!nullToAbsent || servings != null) {
      map['servings'] = Variable<double>(servings);
    }
    if (!nullToAbsent || mealId != null) {
      map['meal_id'] = Variable<String>(mealId);
    }
    if (!nullToAbsent || adhocName != null) {
      map['adhoc_name'] = Variable<String>(adhocName);
    }
    if (!nullToAbsent || adhocCalories != null) {
      map['adhoc_calories'] = Variable<double>(adhocCalories);
    }
    if (!nullToAbsent || adhocProtein != null) {
      map['adhoc_protein'] = Variable<double>(adhocProtein);
    }
    if (!nullToAbsent || adhocCarbs != null) {
      map['adhoc_carbs'] = Variable<double>(adhocCarbs);
    }
    if (!nullToAbsent || adhocFat != null) {
      map['adhoc_fat'] = Variable<double>(adhocFat);
    }
    return map;
  }

  FoodLogEntriesCompanion toCompanion(bool nullToAbsent) {
    return FoodLogEntriesCompanion(
      id: Value(id),
      logDate: Value(logDate),
      foodItemId: foodItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(foodItemId),
      servings: servings == null && nullToAbsent
          ? const Value.absent()
          : Value(servings),
      mealId: mealId == null && nullToAbsent
          ? const Value.absent()
          : Value(mealId),
      adhocName: adhocName == null && nullToAbsent
          ? const Value.absent()
          : Value(adhocName),
      adhocCalories: adhocCalories == null && nullToAbsent
          ? const Value.absent()
          : Value(adhocCalories),
      adhocProtein: adhocProtein == null && nullToAbsent
          ? const Value.absent()
          : Value(adhocProtein),
      adhocCarbs: adhocCarbs == null && nullToAbsent
          ? const Value.absent()
          : Value(adhocCarbs),
      adhocFat: adhocFat == null && nullToAbsent
          ? const Value.absent()
          : Value(adhocFat),
    );
  }

  factory FoodLogEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodLogEntry(
      id: serializer.fromJson<String>(json['id']),
      logDate: serializer.fromJson<DateTime>(json['logDate']),
      foodItemId: serializer.fromJson<String?>(json['foodItemId']),
      servings: serializer.fromJson<double?>(json['servings']),
      mealId: serializer.fromJson<String?>(json['mealId']),
      adhocName: serializer.fromJson<String?>(json['adhocName']),
      adhocCalories: serializer.fromJson<double?>(json['adhocCalories']),
      adhocProtein: serializer.fromJson<double?>(json['adhocProtein']),
      adhocCarbs: serializer.fromJson<double?>(json['adhocCarbs']),
      adhocFat: serializer.fromJson<double?>(json['adhocFat']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'logDate': serializer.toJson<DateTime>(logDate),
      'foodItemId': serializer.toJson<String?>(foodItemId),
      'servings': serializer.toJson<double?>(servings),
      'mealId': serializer.toJson<String?>(mealId),
      'adhocName': serializer.toJson<String?>(adhocName),
      'adhocCalories': serializer.toJson<double?>(adhocCalories),
      'adhocProtein': serializer.toJson<double?>(adhocProtein),
      'adhocCarbs': serializer.toJson<double?>(adhocCarbs),
      'adhocFat': serializer.toJson<double?>(adhocFat),
    };
  }

  FoodLogEntry copyWith({
    String? id,
    DateTime? logDate,
    Value<String?> foodItemId = const Value.absent(),
    Value<double?> servings = const Value.absent(),
    Value<String?> mealId = const Value.absent(),
    Value<String?> adhocName = const Value.absent(),
    Value<double?> adhocCalories = const Value.absent(),
    Value<double?> adhocProtein = const Value.absent(),
    Value<double?> adhocCarbs = const Value.absent(),
    Value<double?> adhocFat = const Value.absent(),
  }) => FoodLogEntry(
    id: id ?? this.id,
    logDate: logDate ?? this.logDate,
    foodItemId: foodItemId.present ? foodItemId.value : this.foodItemId,
    servings: servings.present ? servings.value : this.servings,
    mealId: mealId.present ? mealId.value : this.mealId,
    adhocName: adhocName.present ? adhocName.value : this.adhocName,
    adhocCalories: adhocCalories.present
        ? adhocCalories.value
        : this.adhocCalories,
    adhocProtein: adhocProtein.present ? adhocProtein.value : this.adhocProtein,
    adhocCarbs: adhocCarbs.present ? adhocCarbs.value : this.adhocCarbs,
    adhocFat: adhocFat.present ? adhocFat.value : this.adhocFat,
  );
  FoodLogEntry copyWithCompanion(FoodLogEntriesCompanion data) {
    return FoodLogEntry(
      id: data.id.present ? data.id.value : this.id,
      logDate: data.logDate.present ? data.logDate.value : this.logDate,
      foodItemId: data.foodItemId.present
          ? data.foodItemId.value
          : this.foodItemId,
      servings: data.servings.present ? data.servings.value : this.servings,
      mealId: data.mealId.present ? data.mealId.value : this.mealId,
      adhocName: data.adhocName.present ? data.adhocName.value : this.adhocName,
      adhocCalories: data.adhocCalories.present
          ? data.adhocCalories.value
          : this.adhocCalories,
      adhocProtein: data.adhocProtein.present
          ? data.adhocProtein.value
          : this.adhocProtein,
      adhocCarbs: data.adhocCarbs.present
          ? data.adhocCarbs.value
          : this.adhocCarbs,
      adhocFat: data.adhocFat.present ? data.adhocFat.value : this.adhocFat,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodLogEntry(')
          ..write('id: $id, ')
          ..write('logDate: $logDate, ')
          ..write('foodItemId: $foodItemId, ')
          ..write('servings: $servings, ')
          ..write('mealId: $mealId, ')
          ..write('adhocName: $adhocName, ')
          ..write('adhocCalories: $adhocCalories, ')
          ..write('adhocProtein: $adhocProtein, ')
          ..write('adhocCarbs: $adhocCarbs, ')
          ..write('adhocFat: $adhocFat')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    logDate,
    foodItemId,
    servings,
    mealId,
    adhocName,
    adhocCalories,
    adhocProtein,
    adhocCarbs,
    adhocFat,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodLogEntry &&
          other.id == this.id &&
          other.logDate == this.logDate &&
          other.foodItemId == this.foodItemId &&
          other.servings == this.servings &&
          other.mealId == this.mealId &&
          other.adhocName == this.adhocName &&
          other.adhocCalories == this.adhocCalories &&
          other.adhocProtein == this.adhocProtein &&
          other.adhocCarbs == this.adhocCarbs &&
          other.adhocFat == this.adhocFat);
}

class FoodLogEntriesCompanion extends UpdateCompanion<FoodLogEntry> {
  final Value<String> id;
  final Value<DateTime> logDate;
  final Value<String?> foodItemId;
  final Value<double?> servings;
  final Value<String?> mealId;
  final Value<String?> adhocName;
  final Value<double?> adhocCalories;
  final Value<double?> adhocProtein;
  final Value<double?> adhocCarbs;
  final Value<double?> adhocFat;
  final Value<int> rowid;
  const FoodLogEntriesCompanion({
    this.id = const Value.absent(),
    this.logDate = const Value.absent(),
    this.foodItemId = const Value.absent(),
    this.servings = const Value.absent(),
    this.mealId = const Value.absent(),
    this.adhocName = const Value.absent(),
    this.adhocCalories = const Value.absent(),
    this.adhocProtein = const Value.absent(),
    this.adhocCarbs = const Value.absent(),
    this.adhocFat = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoodLogEntriesCompanion.insert({
    required String id,
    required DateTime logDate,
    this.foodItemId = const Value.absent(),
    this.servings = const Value.absent(),
    this.mealId = const Value.absent(),
    this.adhocName = const Value.absent(),
    this.adhocCalories = const Value.absent(),
    this.adhocProtein = const Value.absent(),
    this.adhocCarbs = const Value.absent(),
    this.adhocFat = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       logDate = Value(logDate);
  static Insertable<FoodLogEntry> custom({
    Expression<String>? id,
    Expression<DateTime>? logDate,
    Expression<String>? foodItemId,
    Expression<double>? servings,
    Expression<String>? mealId,
    Expression<String>? adhocName,
    Expression<double>? adhocCalories,
    Expression<double>? adhocProtein,
    Expression<double>? adhocCarbs,
    Expression<double>? adhocFat,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (logDate != null) 'log_date': logDate,
      if (foodItemId != null) 'food_item_id': foodItemId,
      if (servings != null) 'servings': servings,
      if (mealId != null) 'meal_id': mealId,
      if (adhocName != null) 'adhoc_name': adhocName,
      if (adhocCalories != null) 'adhoc_calories': adhocCalories,
      if (adhocProtein != null) 'adhoc_protein': adhocProtein,
      if (adhocCarbs != null) 'adhoc_carbs': adhocCarbs,
      if (adhocFat != null) 'adhoc_fat': adhocFat,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoodLogEntriesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? logDate,
    Value<String?>? foodItemId,
    Value<double?>? servings,
    Value<String?>? mealId,
    Value<String?>? adhocName,
    Value<double?>? adhocCalories,
    Value<double?>? adhocProtein,
    Value<double?>? adhocCarbs,
    Value<double?>? adhocFat,
    Value<int>? rowid,
  }) {
    return FoodLogEntriesCompanion(
      id: id ?? this.id,
      logDate: logDate ?? this.logDate,
      foodItemId: foodItemId ?? this.foodItemId,
      servings: servings ?? this.servings,
      mealId: mealId ?? this.mealId,
      adhocName: adhocName ?? this.adhocName,
      adhocCalories: adhocCalories ?? this.adhocCalories,
      adhocProtein: adhocProtein ?? this.adhocProtein,
      adhocCarbs: adhocCarbs ?? this.adhocCarbs,
      adhocFat: adhocFat ?? this.adhocFat,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (logDate.present) {
      map['log_date'] = Variable<DateTime>(logDate.value);
    }
    if (foodItemId.present) {
      map['food_item_id'] = Variable<String>(foodItemId.value);
    }
    if (servings.present) {
      map['servings'] = Variable<double>(servings.value);
    }
    if (mealId.present) {
      map['meal_id'] = Variable<String>(mealId.value);
    }
    if (adhocName.present) {
      map['adhoc_name'] = Variable<String>(adhocName.value);
    }
    if (adhocCalories.present) {
      map['adhoc_calories'] = Variable<double>(adhocCalories.value);
    }
    if (adhocProtein.present) {
      map['adhoc_protein'] = Variable<double>(adhocProtein.value);
    }
    if (adhocCarbs.present) {
      map['adhoc_carbs'] = Variable<double>(adhocCarbs.value);
    }
    if (adhocFat.present) {
      map['adhoc_fat'] = Variable<double>(adhocFat.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodLogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('logDate: $logDate, ')
          ..write('foodItemId: $foodItemId, ')
          ..write('servings: $servings, ')
          ..write('mealId: $mealId, ')
          ..write('adhocName: $adhocName, ')
          ..write('adhocCalories: $adhocCalories, ')
          ..write('adhocProtein: $adhocProtein, ')
          ..write('adhocCarbs: $adhocCarbs, ')
          ..write('adhocFat: $adhocFat, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FoodItemsTable foodItems = $FoodItemsTable(this);
  late final $MealsTable meals = $MealsTable(this);
  late final $MealFoodItemsTable mealFoodItems = $MealFoodItemsTable(this);
  late final $FoodLogEntriesTable foodLogEntries = $FoodLogEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    foodItems,
    meals,
    mealFoodItems,
    foodLogEntries,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('meal_food_items', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$FoodItemsTableCreateCompanionBuilder =
    FoodItemsCompanion Function({
      required String id,
      required String name,
      required double calories,
      required double protein,
      required double carbs,
      required double fat,
      required double servingWeight,
      required String weightUnit,
      Value<int> rowid,
    });
typedef $$FoodItemsTableUpdateCompanionBuilder =
    FoodItemsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<double> calories,
      Value<double> protein,
      Value<double> carbs,
      Value<double> fat,
      Value<double> servingWeight,
      Value<String> weightUnit,
      Value<int> rowid,
    });

final class $$FoodItemsTableReferences
    extends BaseReferences<_$AppDatabase, $FoodItemsTable, FoodItem> {
  $$FoodItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MealFoodItemsTable, List<MealFoodItem>>
  _mealFoodItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mealFoodItems,
    aliasName: $_aliasNameGenerator(
      db.foodItems.id,
      db.mealFoodItems.foodItemId,
    ),
  );

  $$MealFoodItemsTableProcessedTableManager get mealFoodItemsRefs {
    final manager = $$MealFoodItemsTableTableManager(
      $_db,
      $_db.mealFoodItems,
    ).filter((f) => f.foodItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_mealFoodItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FoodLogEntriesTable, List<FoodLogEntry>>
  _foodLogEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.foodLogEntries,
    aliasName: $_aliasNameGenerator(
      db.foodItems.id,
      db.foodLogEntries.foodItemId,
    ),
  );

  $$FoodLogEntriesTableProcessedTableManager get foodLogEntriesRefs {
    final manager = $$FoodLogEntriesTableTableManager(
      $_db,
      $_db.foodLogEntries,
    ).filter((f) => f.foodItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_foodLogEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoodItemsTableFilterComposer
    extends Composer<_$AppDatabase, $FoodItemsTable> {
  $$FoodItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbs => $composableBuilder(
    column: $table.carbs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fat => $composableBuilder(
    column: $table.fat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get servingWeight => $composableBuilder(
    column: $table.servingWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weightUnit => $composableBuilder(
    column: $table.weightUnit,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mealFoodItemsRefs(
    Expression<bool> Function($$MealFoodItemsTableFilterComposer f) f,
  ) {
    final $$MealFoodItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealFoodItems,
      getReferencedColumn: (t) => t.foodItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealFoodItemsTableFilterComposer(
            $db: $db,
            $table: $db.mealFoodItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> foodLogEntriesRefs(
    Expression<bool> Function($$FoodLogEntriesTableFilterComposer f) f,
  ) {
    final $$FoodLogEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.foodLogEntries,
      getReferencedColumn: (t) => t.foodItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodLogEntriesTableFilterComposer(
            $db: $db,
            $table: $db.foodLogEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoodItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodItemsTable> {
  $$FoodItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbs => $composableBuilder(
    column: $table.carbs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fat => $composableBuilder(
    column: $table.fat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get servingWeight => $composableBuilder(
    column: $table.servingWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weightUnit => $composableBuilder(
    column: $table.weightUnit,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoodItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodItemsTable> {
  $$FoodItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get calories =>
      $composableBuilder(column: $table.calories, builder: (column) => column);

  GeneratedColumn<double> get protein =>
      $composableBuilder(column: $table.protein, builder: (column) => column);

  GeneratedColumn<double> get carbs =>
      $composableBuilder(column: $table.carbs, builder: (column) => column);

  GeneratedColumn<double> get fat =>
      $composableBuilder(column: $table.fat, builder: (column) => column);

  GeneratedColumn<double> get servingWeight => $composableBuilder(
    column: $table.servingWeight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weightUnit => $composableBuilder(
    column: $table.weightUnit,
    builder: (column) => column,
  );

  Expression<T> mealFoodItemsRefs<T extends Object>(
    Expression<T> Function($$MealFoodItemsTableAnnotationComposer a) f,
  ) {
    final $$MealFoodItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealFoodItems,
      getReferencedColumn: (t) => t.foodItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealFoodItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.mealFoodItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> foodLogEntriesRefs<T extends Object>(
    Expression<T> Function($$FoodLogEntriesTableAnnotationComposer a) f,
  ) {
    final $$FoodLogEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.foodLogEntries,
      getReferencedColumn: (t) => t.foodItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodLogEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.foodLogEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoodItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodItemsTable,
          FoodItem,
          $$FoodItemsTableFilterComposer,
          $$FoodItemsTableOrderingComposer,
          $$FoodItemsTableAnnotationComposer,
          $$FoodItemsTableCreateCompanionBuilder,
          $$FoodItemsTableUpdateCompanionBuilder,
          (FoodItem, $$FoodItemsTableReferences),
          FoodItem,
          PrefetchHooks Function({
            bool mealFoodItemsRefs,
            bool foodLogEntriesRefs,
          })
        > {
  $$FoodItemsTableTableManager(_$AppDatabase db, $FoodItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> calories = const Value.absent(),
                Value<double> protein = const Value.absent(),
                Value<double> carbs = const Value.absent(),
                Value<double> fat = const Value.absent(),
                Value<double> servingWeight = const Value.absent(),
                Value<String> weightUnit = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoodItemsCompanion(
                id: id,
                name: name,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                servingWeight: servingWeight,
                weightUnit: weightUnit,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required double calories,
                required double protein,
                required double carbs,
                required double fat,
                required double servingWeight,
                required String weightUnit,
                Value<int> rowid = const Value.absent(),
              }) => FoodItemsCompanion.insert(
                id: id,
                name: name,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                servingWeight: servingWeight,
                weightUnit: weightUnit,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FoodItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({mealFoodItemsRefs = false, foodLogEntriesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mealFoodItemsRefs) db.mealFoodItems,
                    if (foodLogEntriesRefs) db.foodLogEntries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mealFoodItemsRefs)
                        await $_getPrefetchedData<
                          FoodItem,
                          $FoodItemsTable,
                          MealFoodItem
                        >(
                          currentTable: table,
                          referencedTable: $$FoodItemsTableReferences
                              ._mealFoodItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FoodItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).mealFoodItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.foodItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (foodLogEntriesRefs)
                        await $_getPrefetchedData<
                          FoodItem,
                          $FoodItemsTable,
                          FoodLogEntry
                        >(
                          currentTable: table,
                          referencedTable: $$FoodItemsTableReferences
                              ._foodLogEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FoodItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).foodLogEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.foodItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FoodItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodItemsTable,
      FoodItem,
      $$FoodItemsTableFilterComposer,
      $$FoodItemsTableOrderingComposer,
      $$FoodItemsTableAnnotationComposer,
      $$FoodItemsTableCreateCompanionBuilder,
      $$FoodItemsTableUpdateCompanionBuilder,
      (FoodItem, $$FoodItemsTableReferences),
      FoodItem,
      PrefetchHooks Function({bool mealFoodItemsRefs, bool foodLogEntriesRefs})
    >;
typedef $$MealsTableCreateCompanionBuilder =
    MealsCompanion Function({
      required String id,
      required String name,
      Value<int> rowid,
    });
typedef $$MealsTableUpdateCompanionBuilder =
    MealsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> rowid,
    });

final class $$MealsTableReferences
    extends BaseReferences<_$AppDatabase, $MealsTable, Meal> {
  $$MealsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MealFoodItemsTable, List<MealFoodItem>>
  _mealFoodItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mealFoodItems,
    aliasName: $_aliasNameGenerator(db.meals.id, db.mealFoodItems.mealId),
  );

  $$MealFoodItemsTableProcessedTableManager get mealFoodItemsRefs {
    final manager = $$MealFoodItemsTableTableManager(
      $_db,
      $_db.mealFoodItems,
    ).filter((f) => f.mealId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_mealFoodItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FoodLogEntriesTable, List<FoodLogEntry>>
  _foodLogEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.foodLogEntries,
    aliasName: $_aliasNameGenerator(db.meals.id, db.foodLogEntries.mealId),
  );

  $$FoodLogEntriesTableProcessedTableManager get foodLogEntriesRefs {
    final manager = $$FoodLogEntriesTableTableManager(
      $_db,
      $_db.foodLogEntries,
    ).filter((f) => f.mealId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_foodLogEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MealsTableFilterComposer extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mealFoodItemsRefs(
    Expression<bool> Function($$MealFoodItemsTableFilterComposer f) f,
  ) {
    final $$MealFoodItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealFoodItems,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealFoodItemsTableFilterComposer(
            $db: $db,
            $table: $db.mealFoodItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> foodLogEntriesRefs(
    Expression<bool> Function($$FoodLogEntriesTableFilterComposer f) f,
  ) {
    final $$FoodLogEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.foodLogEntries,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodLogEntriesTableFilterComposer(
            $db: $db,
            $table: $db.foodLogEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MealsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> mealFoodItemsRefs<T extends Object>(
    Expression<T> Function($$MealFoodItemsTableAnnotationComposer a) f,
  ) {
    final $$MealFoodItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealFoodItems,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealFoodItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.mealFoodItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> foodLogEntriesRefs<T extends Object>(
    Expression<T> Function($$FoodLogEntriesTableAnnotationComposer a) f,
  ) {
    final $$FoodLogEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.foodLogEntries,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodLogEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.foodLogEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealsTable,
          Meal,
          $$MealsTableFilterComposer,
          $$MealsTableOrderingComposer,
          $$MealsTableAnnotationComposer,
          $$MealsTableCreateCompanionBuilder,
          $$MealsTableUpdateCompanionBuilder,
          (Meal, $$MealsTableReferences),
          Meal,
          PrefetchHooks Function({
            bool mealFoodItemsRefs,
            bool foodLogEntriesRefs,
          })
        > {
  $$MealsTableTableManager(_$AppDatabase db, $MealsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealsCompanion(id: id, name: name, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => MealsCompanion.insert(id: id, name: name, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$MealsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({mealFoodItemsRefs = false, foodLogEntriesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mealFoodItemsRefs) db.mealFoodItems,
                    if (foodLogEntriesRefs) db.foodLogEntries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mealFoodItemsRefs)
                        await $_getPrefetchedData<
                          Meal,
                          $MealsTable,
                          MealFoodItem
                        >(
                          currentTable: table,
                          referencedTable: $$MealsTableReferences
                              ._mealFoodItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MealsTableReferences(
                                db,
                                table,
                                p0,
                              ).mealFoodItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mealId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (foodLogEntriesRefs)
                        await $_getPrefetchedData<
                          Meal,
                          $MealsTable,
                          FoodLogEntry
                        >(
                          currentTable: table,
                          referencedTable: $$MealsTableReferences
                              ._foodLogEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MealsTableReferences(
                                db,
                                table,
                                p0,
                              ).foodLogEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mealId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MealsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealsTable,
      Meal,
      $$MealsTableFilterComposer,
      $$MealsTableOrderingComposer,
      $$MealsTableAnnotationComposer,
      $$MealsTableCreateCompanionBuilder,
      $$MealsTableUpdateCompanionBuilder,
      (Meal, $$MealsTableReferences),
      Meal,
      PrefetchHooks Function({bool mealFoodItemsRefs, bool foodLogEntriesRefs})
    >;
typedef $$MealFoodItemsTableCreateCompanionBuilder =
    MealFoodItemsCompanion Function({
      required String id,
      required String mealId,
      required String foodItemId,
      required double servingWeight,
      required String weightUnit,
      Value<int> rowid,
    });
typedef $$MealFoodItemsTableUpdateCompanionBuilder =
    MealFoodItemsCompanion Function({
      Value<String> id,
      Value<String> mealId,
      Value<String> foodItemId,
      Value<double> servingWeight,
      Value<String> weightUnit,
      Value<int> rowid,
    });

final class $$MealFoodItemsTableReferences
    extends BaseReferences<_$AppDatabase, $MealFoodItemsTable, MealFoodItem> {
  $$MealFoodItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MealsTable _mealIdTable(_$AppDatabase db) => db.meals.createAlias(
    $_aliasNameGenerator(db.mealFoodItems.mealId, db.meals.id),
  );

  $$MealsTableProcessedTableManager get mealId {
    final $_column = $_itemColumn<String>('meal_id')!;

    final manager = $$MealsTableTableManager(
      $_db,
      $_db.meals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mealIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $FoodItemsTable _foodItemIdTable(_$AppDatabase db) =>
      db.foodItems.createAlias(
        $_aliasNameGenerator(db.mealFoodItems.foodItemId, db.foodItems.id),
      );

  $$FoodItemsTableProcessedTableManager get foodItemId {
    final $_column = $_itemColumn<String>('food_item_id')!;

    final manager = $$FoodItemsTableTableManager(
      $_db,
      $_db.foodItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_foodItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MealFoodItemsTableFilterComposer
    extends Composer<_$AppDatabase, $MealFoodItemsTable> {
  $$MealFoodItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get servingWeight => $composableBuilder(
    column: $table.servingWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weightUnit => $composableBuilder(
    column: $table.weightUnit,
    builder: (column) => ColumnFilters(column),
  );

  $$MealsTableFilterComposer get mealId {
    final $$MealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableFilterComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoodItemsTableFilterComposer get foodItemId {
    final $$FoodItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodItemId,
      referencedTable: $db.foodItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodItemsTableFilterComposer(
            $db: $db,
            $table: $db.foodItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealFoodItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealFoodItemsTable> {
  $$MealFoodItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get servingWeight => $composableBuilder(
    column: $table.servingWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weightUnit => $composableBuilder(
    column: $table.weightUnit,
    builder: (column) => ColumnOrderings(column),
  );

  $$MealsTableOrderingComposer get mealId {
    final $$MealsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableOrderingComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoodItemsTableOrderingComposer get foodItemId {
    final $$FoodItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodItemId,
      referencedTable: $db.foodItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodItemsTableOrderingComposer(
            $db: $db,
            $table: $db.foodItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealFoodItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealFoodItemsTable> {
  $$MealFoodItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get servingWeight => $composableBuilder(
    column: $table.servingWeight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weightUnit => $composableBuilder(
    column: $table.weightUnit,
    builder: (column) => column,
  );

  $$MealsTableAnnotationComposer get mealId {
    final $$MealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableAnnotationComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoodItemsTableAnnotationComposer get foodItemId {
    final $$FoodItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodItemId,
      referencedTable: $db.foodItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.foodItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealFoodItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealFoodItemsTable,
          MealFoodItem,
          $$MealFoodItemsTableFilterComposer,
          $$MealFoodItemsTableOrderingComposer,
          $$MealFoodItemsTableAnnotationComposer,
          $$MealFoodItemsTableCreateCompanionBuilder,
          $$MealFoodItemsTableUpdateCompanionBuilder,
          (MealFoodItem, $$MealFoodItemsTableReferences),
          MealFoodItem,
          PrefetchHooks Function({bool mealId, bool foodItemId})
        > {
  $$MealFoodItemsTableTableManager(_$AppDatabase db, $MealFoodItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealFoodItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealFoodItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealFoodItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> mealId = const Value.absent(),
                Value<String> foodItemId = const Value.absent(),
                Value<double> servingWeight = const Value.absent(),
                Value<String> weightUnit = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealFoodItemsCompanion(
                id: id,
                mealId: mealId,
                foodItemId: foodItemId,
                servingWeight: servingWeight,
                weightUnit: weightUnit,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String mealId,
                required String foodItemId,
                required double servingWeight,
                required String weightUnit,
                Value<int> rowid = const Value.absent(),
              }) => MealFoodItemsCompanion.insert(
                id: id,
                mealId: mealId,
                foodItemId: foodItemId,
                servingWeight: servingWeight,
                weightUnit: weightUnit,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MealFoodItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mealId = false, foodItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mealId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mealId,
                                referencedTable: $$MealFoodItemsTableReferences
                                    ._mealIdTable(db),
                                referencedColumn: $$MealFoodItemsTableReferences
                                    ._mealIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (foodItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.foodItemId,
                                referencedTable: $$MealFoodItemsTableReferences
                                    ._foodItemIdTable(db),
                                referencedColumn: $$MealFoodItemsTableReferences
                                    ._foodItemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MealFoodItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealFoodItemsTable,
      MealFoodItem,
      $$MealFoodItemsTableFilterComposer,
      $$MealFoodItemsTableOrderingComposer,
      $$MealFoodItemsTableAnnotationComposer,
      $$MealFoodItemsTableCreateCompanionBuilder,
      $$MealFoodItemsTableUpdateCompanionBuilder,
      (MealFoodItem, $$MealFoodItemsTableReferences),
      MealFoodItem,
      PrefetchHooks Function({bool mealId, bool foodItemId})
    >;
typedef $$FoodLogEntriesTableCreateCompanionBuilder =
    FoodLogEntriesCompanion Function({
      required String id,
      required DateTime logDate,
      Value<String?> foodItemId,
      Value<double?> servings,
      Value<String?> mealId,
      Value<String?> adhocName,
      Value<double?> adhocCalories,
      Value<double?> adhocProtein,
      Value<double?> adhocCarbs,
      Value<double?> adhocFat,
      Value<int> rowid,
    });
typedef $$FoodLogEntriesTableUpdateCompanionBuilder =
    FoodLogEntriesCompanion Function({
      Value<String> id,
      Value<DateTime> logDate,
      Value<String?> foodItemId,
      Value<double?> servings,
      Value<String?> mealId,
      Value<String?> adhocName,
      Value<double?> adhocCalories,
      Value<double?> adhocProtein,
      Value<double?> adhocCarbs,
      Value<double?> adhocFat,
      Value<int> rowid,
    });

final class $$FoodLogEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $FoodLogEntriesTable, FoodLogEntry> {
  $$FoodLogEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FoodItemsTable _foodItemIdTable(_$AppDatabase db) =>
      db.foodItems.createAlias(
        $_aliasNameGenerator(db.foodLogEntries.foodItemId, db.foodItems.id),
      );

  $$FoodItemsTableProcessedTableManager? get foodItemId {
    final $_column = $_itemColumn<String>('food_item_id');
    if ($_column == null) return null;
    final manager = $$FoodItemsTableTableManager(
      $_db,
      $_db.foodItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_foodItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MealsTable _mealIdTable(_$AppDatabase db) => db.meals.createAlias(
    $_aliasNameGenerator(db.foodLogEntries.mealId, db.meals.id),
  );

  $$MealsTableProcessedTableManager? get mealId {
    final $_column = $_itemColumn<String>('meal_id');
    if ($_column == null) return null;
    final manager = $$MealsTableTableManager(
      $_db,
      $_db.meals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mealIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FoodLogEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $FoodLogEntriesTable> {
  $$FoodLogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get logDate => $composableBuilder(
    column: $table.logDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get servings => $composableBuilder(
    column: $table.servings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get adhocName => $composableBuilder(
    column: $table.adhocName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get adhocCalories => $composableBuilder(
    column: $table.adhocCalories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get adhocProtein => $composableBuilder(
    column: $table.adhocProtein,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get adhocCarbs => $composableBuilder(
    column: $table.adhocCarbs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get adhocFat => $composableBuilder(
    column: $table.adhocFat,
    builder: (column) => ColumnFilters(column),
  );

  $$FoodItemsTableFilterComposer get foodItemId {
    final $$FoodItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodItemId,
      referencedTable: $db.foodItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodItemsTableFilterComposer(
            $db: $db,
            $table: $db.foodItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MealsTableFilterComposer get mealId {
    final $$MealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableFilterComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoodLogEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodLogEntriesTable> {
  $$FoodLogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get logDate => $composableBuilder(
    column: $table.logDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get servings => $composableBuilder(
    column: $table.servings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get adhocName => $composableBuilder(
    column: $table.adhocName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get adhocCalories => $composableBuilder(
    column: $table.adhocCalories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get adhocProtein => $composableBuilder(
    column: $table.adhocProtein,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get adhocCarbs => $composableBuilder(
    column: $table.adhocCarbs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get adhocFat => $composableBuilder(
    column: $table.adhocFat,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoodItemsTableOrderingComposer get foodItemId {
    final $$FoodItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodItemId,
      referencedTable: $db.foodItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodItemsTableOrderingComposer(
            $db: $db,
            $table: $db.foodItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MealsTableOrderingComposer get mealId {
    final $$MealsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableOrderingComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoodLogEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodLogEntriesTable> {
  $$FoodLogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get logDate =>
      $composableBuilder(column: $table.logDate, builder: (column) => column);

  GeneratedColumn<double> get servings =>
      $composableBuilder(column: $table.servings, builder: (column) => column);

  GeneratedColumn<String> get adhocName =>
      $composableBuilder(column: $table.adhocName, builder: (column) => column);

  GeneratedColumn<double> get adhocCalories => $composableBuilder(
    column: $table.adhocCalories,
    builder: (column) => column,
  );

  GeneratedColumn<double> get adhocProtein => $composableBuilder(
    column: $table.adhocProtein,
    builder: (column) => column,
  );

  GeneratedColumn<double> get adhocCarbs => $composableBuilder(
    column: $table.adhocCarbs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get adhocFat =>
      $composableBuilder(column: $table.adhocFat, builder: (column) => column);

  $$FoodItemsTableAnnotationComposer get foodItemId {
    final $$FoodItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodItemId,
      referencedTable: $db.foodItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.foodItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MealsTableAnnotationComposer get mealId {
    final $$MealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableAnnotationComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoodLogEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodLogEntriesTable,
          FoodLogEntry,
          $$FoodLogEntriesTableFilterComposer,
          $$FoodLogEntriesTableOrderingComposer,
          $$FoodLogEntriesTableAnnotationComposer,
          $$FoodLogEntriesTableCreateCompanionBuilder,
          $$FoodLogEntriesTableUpdateCompanionBuilder,
          (FoodLogEntry, $$FoodLogEntriesTableReferences),
          FoodLogEntry,
          PrefetchHooks Function({bool foodItemId, bool mealId})
        > {
  $$FoodLogEntriesTableTableManager(
    _$AppDatabase db,
    $FoodLogEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodLogEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodLogEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodLogEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> logDate = const Value.absent(),
                Value<String?> foodItemId = const Value.absent(),
                Value<double?> servings = const Value.absent(),
                Value<String?> mealId = const Value.absent(),
                Value<String?> adhocName = const Value.absent(),
                Value<double?> adhocCalories = const Value.absent(),
                Value<double?> adhocProtein = const Value.absent(),
                Value<double?> adhocCarbs = const Value.absent(),
                Value<double?> adhocFat = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoodLogEntriesCompanion(
                id: id,
                logDate: logDate,
                foodItemId: foodItemId,
                servings: servings,
                mealId: mealId,
                adhocName: adhocName,
                adhocCalories: adhocCalories,
                adhocProtein: adhocProtein,
                adhocCarbs: adhocCarbs,
                adhocFat: adhocFat,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime logDate,
                Value<String?> foodItemId = const Value.absent(),
                Value<double?> servings = const Value.absent(),
                Value<String?> mealId = const Value.absent(),
                Value<String?> adhocName = const Value.absent(),
                Value<double?> adhocCalories = const Value.absent(),
                Value<double?> adhocProtein = const Value.absent(),
                Value<double?> adhocCarbs = const Value.absent(),
                Value<double?> adhocFat = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoodLogEntriesCompanion.insert(
                id: id,
                logDate: logDate,
                foodItemId: foodItemId,
                servings: servings,
                mealId: mealId,
                adhocName: adhocName,
                adhocCalories: adhocCalories,
                adhocProtein: adhocProtein,
                adhocCarbs: adhocCarbs,
                adhocFat: adhocFat,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FoodLogEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({foodItemId = false, mealId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (foodItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.foodItemId,
                                referencedTable: $$FoodLogEntriesTableReferences
                                    ._foodItemIdTable(db),
                                referencedColumn:
                                    $$FoodLogEntriesTableReferences
                                        ._foodItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (mealId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mealId,
                                referencedTable: $$FoodLogEntriesTableReferences
                                    ._mealIdTable(db),
                                referencedColumn:
                                    $$FoodLogEntriesTableReferences
                                        ._mealIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FoodLogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodLogEntriesTable,
      FoodLogEntry,
      $$FoodLogEntriesTableFilterComposer,
      $$FoodLogEntriesTableOrderingComposer,
      $$FoodLogEntriesTableAnnotationComposer,
      $$FoodLogEntriesTableCreateCompanionBuilder,
      $$FoodLogEntriesTableUpdateCompanionBuilder,
      (FoodLogEntry, $$FoodLogEntriesTableReferences),
      FoodLogEntry,
      PrefetchHooks Function({bool foodItemId, bool mealId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FoodItemsTableTableManager get foodItems =>
      $$FoodItemsTableTableManager(_db, _db.foodItems);
  $$MealsTableTableManager get meals =>
      $$MealsTableTableManager(_db, _db.meals);
  $$MealFoodItemsTableTableManager get mealFoodItems =>
      $$MealFoodItemsTableTableManager(_db, _db.mealFoodItems);
  $$FoodLogEntriesTableTableManager get foodLogEntries =>
      $$FoodLogEntriesTableTableManager(_db, _db.foodLogEntries);
}

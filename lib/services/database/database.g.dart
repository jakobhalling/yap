// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $HistoryTable extends History with TableInfo<$HistoryTable, HistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _rawTranscriptMeta =
      const VerificationMeta('rawTranscript');
  @override
  late final GeneratedColumn<String> rawTranscript = GeneratedColumn<String>(
      'raw_transcript', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _profileNameMeta =
      const VerificationMeta('profileName');
  @override
  late final GeneratedColumn<String> profileName = GeneratedColumn<String>(
      'profile_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _profilePromptMeta =
      const VerificationMeta('profilePrompt');
  @override
  late final GeneratedColumn<String> profilePrompt = GeneratedColumn<String>(
      'profile_prompt', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _processedTextMeta =
      const VerificationMeta('processedText');
  @override
  late final GeneratedColumn<String> processedText = GeneratedColumn<String>(
      'processed_text', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pastedTextMeta =
      const VerificationMeta('pastedText');
  @override
  late final GeneratedColumn<String> pastedText = GeneratedColumn<String>(
      'pasted_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<double> durationSeconds = GeneratedColumn<double>(
      'duration_seconds', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        createdAt,
        rawTranscript,
        profileName,
        profilePrompt,
        processedText,
        pastedText,
        durationSeconds
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history';
  @override
  VerificationContext validateIntegrity(Insertable<HistoryData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('raw_transcript')) {
      context.handle(
          _rawTranscriptMeta,
          rawTranscript.isAcceptableOrUnknown(
              data['raw_transcript']!, _rawTranscriptMeta));
    } else if (isInserting) {
      context.missing(_rawTranscriptMeta);
    }
    if (data.containsKey('profile_name')) {
      context.handle(
          _profileNameMeta,
          profileName.isAcceptableOrUnknown(
              data['profile_name']!, _profileNameMeta));
    }
    if (data.containsKey('profile_prompt')) {
      context.handle(
          _profilePromptMeta,
          profilePrompt.isAcceptableOrUnknown(
              data['profile_prompt']!, _profilePromptMeta));
    }
    if (data.containsKey('processed_text')) {
      context.handle(
          _processedTextMeta,
          processedText.isAcceptableOrUnknown(
              data['processed_text']!, _processedTextMeta));
    }
    if (data.containsKey('pasted_text')) {
      context.handle(
          _pastedTextMeta,
          pastedText.isAcceptableOrUnknown(
              data['pasted_text']!, _pastedTextMeta));
    } else if (isInserting) {
      context.missing(_pastedTextMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      rawTranscript: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_transcript'])!,
      profileName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile_name']),
      profilePrompt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile_prompt']),
      processedText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}processed_text']),
      pastedText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pasted_text'])!,
      durationSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}duration_seconds']),
    );
  }

  @override
  $HistoryTable createAlias(String alias) {
    return $HistoryTable(attachedDatabase, alias);
  }
}

class HistoryData extends DataClass implements Insertable<HistoryData> {
  final int id;
  final DateTime createdAt;
  final String rawTranscript;
  final String? profileName;
  final String? profilePrompt;
  final String? processedText;
  final String pastedText;
  final double? durationSeconds;
  const HistoryData(
      {required this.id,
      required this.createdAt,
      required this.rawTranscript,
      this.profileName,
      this.profilePrompt,
      this.processedText,
      required this.pastedText,
      this.durationSeconds});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['raw_transcript'] = Variable<String>(rawTranscript);
    if (!nullToAbsent || profileName != null) {
      map['profile_name'] = Variable<String>(profileName);
    }
    if (!nullToAbsent || profilePrompt != null) {
      map['profile_prompt'] = Variable<String>(profilePrompt);
    }
    if (!nullToAbsent || processedText != null) {
      map['processed_text'] = Variable<String>(processedText);
    }
    map['pasted_text'] = Variable<String>(pastedText);
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<double>(durationSeconds);
    }
    return map;
  }

  HistoryCompanion toCompanion(bool nullToAbsent) {
    return HistoryCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      rawTranscript: Value(rawTranscript),
      profileName: profileName == null && nullToAbsent
          ? const Value.absent()
          : Value(profileName),
      profilePrompt: profilePrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(profilePrompt),
      processedText: processedText == null && nullToAbsent
          ? const Value.absent()
          : Value(processedText),
      pastedText: Value(pastedText),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
    );
  }

  factory HistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryData(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      rawTranscript: serializer.fromJson<String>(json['rawTranscript']),
      profileName: serializer.fromJson<String?>(json['profileName']),
      profilePrompt: serializer.fromJson<String?>(json['profilePrompt']),
      processedText: serializer.fromJson<String?>(json['processedText']),
      pastedText: serializer.fromJson<String>(json['pastedText']),
      durationSeconds: serializer.fromJson<double?>(json['durationSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'rawTranscript': serializer.toJson<String>(rawTranscript),
      'profileName': serializer.toJson<String?>(profileName),
      'profilePrompt': serializer.toJson<String?>(profilePrompt),
      'processedText': serializer.toJson<String?>(processedText),
      'pastedText': serializer.toJson<String>(pastedText),
      'durationSeconds': serializer.toJson<double?>(durationSeconds),
    };
  }

  HistoryData copyWith(
          {int? id,
          DateTime? createdAt,
          String? rawTranscript,
          Value<String?> profileName = const Value.absent(),
          Value<String?> profilePrompt = const Value.absent(),
          Value<String?> processedText = const Value.absent(),
          String? pastedText,
          Value<double?> durationSeconds = const Value.absent()}) =>
      HistoryData(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        rawTranscript: rawTranscript ?? this.rawTranscript,
        profileName: profileName.present ? profileName.value : this.profileName,
        profilePrompt:
            profilePrompt.present ? profilePrompt.value : this.profilePrompt,
        processedText:
            processedText.present ? processedText.value : this.processedText,
        pastedText: pastedText ?? this.pastedText,
        durationSeconds: durationSeconds.present
            ? durationSeconds.value
            : this.durationSeconds,
      );
  HistoryData copyWithCompanion(HistoryCompanion data) {
    return HistoryData(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      rawTranscript: data.rawTranscript.present
          ? data.rawTranscript.value
          : this.rawTranscript,
      profileName:
          data.profileName.present ? data.profileName.value : this.profileName,
      profilePrompt: data.profilePrompt.present
          ? data.profilePrompt.value
          : this.profilePrompt,
      processedText: data.processedText.present
          ? data.processedText.value
          : this.processedText,
      pastedText:
          data.pastedText.present ? data.pastedText.value : this.pastedText,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryData(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('rawTranscript: $rawTranscript, ')
          ..write('profileName: $profileName, ')
          ..write('profilePrompt: $profilePrompt, ')
          ..write('processedText: $processedText, ')
          ..write('pastedText: $pastedText, ')
          ..write('durationSeconds: $durationSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdAt, rawTranscript, profileName,
      profilePrompt, processedText, pastedText, durationSeconds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryData &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.rawTranscript == this.rawTranscript &&
          other.profileName == this.profileName &&
          other.profilePrompt == this.profilePrompt &&
          other.processedText == this.processedText &&
          other.pastedText == this.pastedText &&
          other.durationSeconds == this.durationSeconds);
}

class HistoryCompanion extends UpdateCompanion<HistoryData> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<String> rawTranscript;
  final Value<String?> profileName;
  final Value<String?> profilePrompt;
  final Value<String?> processedText;
  final Value<String> pastedText;
  final Value<double?> durationSeconds;
  const HistoryCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rawTranscript = const Value.absent(),
    this.profileName = const Value.absent(),
    this.profilePrompt = const Value.absent(),
    this.processedText = const Value.absent(),
    this.pastedText = const Value.absent(),
    this.durationSeconds = const Value.absent(),
  });
  HistoryCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    required String rawTranscript,
    this.profileName = const Value.absent(),
    this.profilePrompt = const Value.absent(),
    this.processedText = const Value.absent(),
    required String pastedText,
    this.durationSeconds = const Value.absent(),
  })  : rawTranscript = Value(rawTranscript),
        pastedText = Value(pastedText);
  static Insertable<HistoryData> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<String>? rawTranscript,
    Expression<String>? profileName,
    Expression<String>? profilePrompt,
    Expression<String>? processedText,
    Expression<String>? pastedText,
    Expression<double>? durationSeconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (rawTranscript != null) 'raw_transcript': rawTranscript,
      if (profileName != null) 'profile_name': profileName,
      if (profilePrompt != null) 'profile_prompt': profilePrompt,
      if (processedText != null) 'processed_text': processedText,
      if (pastedText != null) 'pasted_text': pastedText,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
    });
  }

  HistoryCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? createdAt,
      Value<String>? rawTranscript,
      Value<String?>? profileName,
      Value<String?>? profilePrompt,
      Value<String?>? processedText,
      Value<String>? pastedText,
      Value<double?>? durationSeconds}) {
    return HistoryCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      rawTranscript: rawTranscript ?? this.rawTranscript,
      profileName: profileName ?? this.profileName,
      profilePrompt: profilePrompt ?? this.profilePrompt,
      processedText: processedText ?? this.processedText,
      pastedText: pastedText ?? this.pastedText,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rawTranscript.present) {
      map['raw_transcript'] = Variable<String>(rawTranscript.value);
    }
    if (profileName.present) {
      map['profile_name'] = Variable<String>(profileName.value);
    }
    if (profilePrompt.present) {
      map['profile_prompt'] = Variable<String>(profilePrompt.value);
    }
    if (processedText.present) {
      map['processed_text'] = Variable<String>(processedText.value);
    }
    if (pastedText.present) {
      map['pasted_text'] = Variable<String>(pastedText.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<double>(durationSeconds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('rawTranscript: $rawTranscript, ')
          ..write('profileName: $profileName, ')
          ..write('profilePrompt: $profilePrompt, ')
          ..write('processedText: $processedText, ')
          ..write('pastedText: $pastedText, ')
          ..write('durationSeconds: $durationSeconds')
          ..write(')'))
        .toString();
  }
}

class $PromptProfilesTable extends PromptProfiles
    with TableInfo<$PromptProfilesTable, PromptProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PromptProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<int> slot = GeneratedColumn<int>(
      'slot', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _systemPromptMeta =
      const VerificationMeta('systemPrompt');
  @override
  late final GeneratedColumn<String> systemPrompt = GeneratedColumn<String>(
      'system_prompt', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isDefaultMeta =
      const VerificationMeta('isDefault');
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
      'is_default', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_default" IN (0, 1))'),
      defaultValue: const Constant(true));
  @override
  List<GeneratedColumn> get $columns => [slot, name, systemPrompt, isDefault];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prompt_profiles';
  @override
  VerificationContext validateIntegrity(Insertable<PromptProfile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('slot')) {
      context.handle(
          _slotMeta, slot.isAcceptableOrUnknown(data['slot']!, _slotMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('system_prompt')) {
      context.handle(
          _systemPromptMeta,
          systemPrompt.isAcceptableOrUnknown(
              data['system_prompt']!, _systemPromptMeta));
    } else if (isInserting) {
      context.missing(_systemPromptMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(_isDefaultMeta,
          isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {slot};
  @override
  PromptProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PromptProfile(
      slot: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}slot'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      systemPrompt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}system_prompt'])!,
      isDefault: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_default'])!,
    );
  }

  @override
  $PromptProfilesTable createAlias(String alias) {
    return $PromptProfilesTable(attachedDatabase, alias);
  }
}

class PromptProfile extends DataClass implements Insertable<PromptProfile> {
  final int slot;
  final String name;
  final String systemPrompt;
  final bool isDefault;
  const PromptProfile(
      {required this.slot,
      required this.name,
      required this.systemPrompt,
      required this.isDefault});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['slot'] = Variable<int>(slot);
    map['name'] = Variable<String>(name);
    map['system_prompt'] = Variable<String>(systemPrompt);
    map['is_default'] = Variable<bool>(isDefault);
    return map;
  }

  PromptProfilesCompanion toCompanion(bool nullToAbsent) {
    return PromptProfilesCompanion(
      slot: Value(slot),
      name: Value(name),
      systemPrompt: Value(systemPrompt),
      isDefault: Value(isDefault),
    );
  }

  factory PromptProfile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PromptProfile(
      slot: serializer.fromJson<int>(json['slot']),
      name: serializer.fromJson<String>(json['name']),
      systemPrompt: serializer.fromJson<String>(json['systemPrompt']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'slot': serializer.toJson<int>(slot),
      'name': serializer.toJson<String>(name),
      'systemPrompt': serializer.toJson<String>(systemPrompt),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  PromptProfile copyWith(
          {int? slot, String? name, String? systemPrompt, bool? isDefault}) =>
      PromptProfile(
        slot: slot ?? this.slot,
        name: name ?? this.name,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        isDefault: isDefault ?? this.isDefault,
      );
  PromptProfile copyWithCompanion(PromptProfilesCompanion data) {
    return PromptProfile(
      slot: data.slot.present ? data.slot.value : this.slot,
      name: data.name.present ? data.name.value : this.name,
      systemPrompt: data.systemPrompt.present
          ? data.systemPrompt.value
          : this.systemPrompt,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PromptProfile(')
          ..write('slot: $slot, ')
          ..write('name: $name, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(slot, name, systemPrompt, isDefault);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptProfile &&
          other.slot == this.slot &&
          other.name == this.name &&
          other.systemPrompt == this.systemPrompt &&
          other.isDefault == this.isDefault);
}

class PromptProfilesCompanion extends UpdateCompanion<PromptProfile> {
  final Value<int> slot;
  final Value<String> name;
  final Value<String> systemPrompt;
  final Value<bool> isDefault;
  const PromptProfilesCompanion({
    this.slot = const Value.absent(),
    this.name = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.isDefault = const Value.absent(),
  });
  PromptProfilesCompanion.insert({
    this.slot = const Value.absent(),
    required String name,
    required String systemPrompt,
    this.isDefault = const Value.absent(),
  })  : name = Value(name),
        systemPrompt = Value(systemPrompt);
  static Insertable<PromptProfile> custom({
    Expression<int>? slot,
    Expression<String>? name,
    Expression<String>? systemPrompt,
    Expression<bool>? isDefault,
  }) {
    return RawValuesInsertable({
      if (slot != null) 'slot': slot,
      if (name != null) 'name': name,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (isDefault != null) 'is_default': isDefault,
    });
  }

  PromptProfilesCompanion copyWith(
      {Value<int>? slot,
      Value<String>? name,
      Value<String>? systemPrompt,
      Value<bool>? isDefault}) {
    return PromptProfilesCompanion(
      slot: slot ?? this.slot,
      name: name ?? this.name,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (slot.present) {
      map['slot'] = Variable<int>(slot.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (systemPrompt.present) {
      map['system_prompt'] = Variable<String>(systemPrompt.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PromptProfilesCompanion(')
          ..write('slot: $slot, ')
          ..write('name: $name, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory Setting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) => Setting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $HistoryTable history = $HistoryTable(this);
  late final $PromptProfilesTable promptProfiles = $PromptProfilesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final HistoryDao historyDao = HistoryDao(this as AppDatabase);
  late final PromptProfileDao promptProfileDao =
      PromptProfileDao(this as AppDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [history, promptProfiles, settings];
}

typedef $$HistoryTableCreateCompanionBuilder = HistoryCompanion Function({
  Value<int> id,
  Value<DateTime> createdAt,
  required String rawTranscript,
  Value<String?> profileName,
  Value<String?> profilePrompt,
  Value<String?> processedText,
  required String pastedText,
  Value<double?> durationSeconds,
});
typedef $$HistoryTableUpdateCompanionBuilder = HistoryCompanion Function({
  Value<int> id,
  Value<DateTime> createdAt,
  Value<String> rawTranscript,
  Value<String?> profileName,
  Value<String?> profilePrompt,
  Value<String?> processedText,
  Value<String> pastedText,
  Value<double?> durationSeconds,
});

class $$HistoryTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HistoryTable,
    HistoryData,
    $$HistoryTableFilterComposer,
    $$HistoryTableOrderingComposer,
    $$HistoryTableCreateCompanionBuilder,
    $$HistoryTableUpdateCompanionBuilder> {
  $$HistoryTableTableManager(_$AppDatabase db, $HistoryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$HistoryTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$HistoryTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> rawTranscript = const Value.absent(),
            Value<String?> profileName = const Value.absent(),
            Value<String?> profilePrompt = const Value.absent(),
            Value<String?> processedText = const Value.absent(),
            Value<String> pastedText = const Value.absent(),
            Value<double?> durationSeconds = const Value.absent(),
          }) =>
              HistoryCompanion(
            id: id,
            createdAt: createdAt,
            rawTranscript: rawTranscript,
            profileName: profileName,
            profilePrompt: profilePrompt,
            processedText: processedText,
            pastedText: pastedText,
            durationSeconds: durationSeconds,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            required String rawTranscript,
            Value<String?> profileName = const Value.absent(),
            Value<String?> profilePrompt = const Value.absent(),
            Value<String?> processedText = const Value.absent(),
            required String pastedText,
            Value<double?> durationSeconds = const Value.absent(),
          }) =>
              HistoryCompanion.insert(
            id: id,
            createdAt: createdAt,
            rawTranscript: rawTranscript,
            profileName: profileName,
            profilePrompt: profilePrompt,
            processedText: processedText,
            pastedText: pastedText,
            durationSeconds: durationSeconds,
          ),
        ));
}

class $$HistoryTableFilterComposer
    extends FilterComposer<_$AppDatabase, $HistoryTable> {
  $$HistoryTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get rawTranscript => $state.composableBuilder(
      column: $state.table.rawTranscript,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get profileName => $state.composableBuilder(
      column: $state.table.profileName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get profilePrompt => $state.composableBuilder(
      column: $state.table.profilePrompt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get processedText => $state.composableBuilder(
      column: $state.table.processedText,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get pastedText => $state.composableBuilder(
      column: $state.table.pastedText,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get durationSeconds => $state.composableBuilder(
      column: $state.table.durationSeconds,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$HistoryTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $HistoryTable> {
  $$HistoryTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get rawTranscript => $state.composableBuilder(
      column: $state.table.rawTranscript,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get profileName => $state.composableBuilder(
      column: $state.table.profileName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get profilePrompt => $state.composableBuilder(
      column: $state.table.profilePrompt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get processedText => $state.composableBuilder(
      column: $state.table.processedText,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get pastedText => $state.composableBuilder(
      column: $state.table.pastedText,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get durationSeconds => $state.composableBuilder(
      column: $state.table.durationSeconds,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$PromptProfilesTableCreateCompanionBuilder = PromptProfilesCompanion
    Function({
  Value<int> slot,
  required String name,
  required String systemPrompt,
  Value<bool> isDefault,
});
typedef $$PromptProfilesTableUpdateCompanionBuilder = PromptProfilesCompanion
    Function({
  Value<int> slot,
  Value<String> name,
  Value<String> systemPrompt,
  Value<bool> isDefault,
});

class $$PromptProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PromptProfilesTable,
    PromptProfile,
    $$PromptProfilesTableFilterComposer,
    $$PromptProfilesTableOrderingComposer,
    $$PromptProfilesTableCreateCompanionBuilder,
    $$PromptProfilesTableUpdateCompanionBuilder> {
  $$PromptProfilesTableTableManager(
      _$AppDatabase db, $PromptProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$PromptProfilesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$PromptProfilesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> slot = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> systemPrompt = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
          }) =>
              PromptProfilesCompanion(
            slot: slot,
            name: name,
            systemPrompt: systemPrompt,
            isDefault: isDefault,
          ),
          createCompanionCallback: ({
            Value<int> slot = const Value.absent(),
            required String name,
            required String systemPrompt,
            Value<bool> isDefault = const Value.absent(),
          }) =>
              PromptProfilesCompanion.insert(
            slot: slot,
            name: name,
            systemPrompt: systemPrompt,
            isDefault: isDefault,
          ),
        ));
}

class $$PromptProfilesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $PromptProfilesTable> {
  $$PromptProfilesTableFilterComposer(super.$state);
  ColumnFilters<int> get slot => $state.composableBuilder(
      column: $state.table.slot,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get systemPrompt => $state.composableBuilder(
      column: $state.table.systemPrompt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isDefault => $state.composableBuilder(
      column: $state.table.isDefault,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$PromptProfilesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $PromptProfilesTable> {
  $$PromptProfilesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get slot => $state.composableBuilder(
      column: $state.table.slot,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get systemPrompt => $state.composableBuilder(
      column: $state.table.systemPrompt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isDefault => $state.composableBuilder(
      column: $state.table.isDefault,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$SettingsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$SettingsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
        ));
}

class $$SettingsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer(super.$state);
  ColumnFilters<String> get key => $state.composableBuilder(
      column: $state.table.key,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get value => $state.composableBuilder(
      column: $state.table.value,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$SettingsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get key => $state.composableBuilder(
      column: $state.table.key,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get value => $state.composableBuilder(
      column: $state.table.value,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$HistoryTableTableManager get history =>
      $$HistoryTableTableManager(_db, _db.history);
  $$PromptProfilesTableTableManager get promptProfiles =>
      $$PromptProfilesTableTableManager(_db, _db.promptProfiles);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}

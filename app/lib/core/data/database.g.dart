// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DecksTable extends Decks with TableInfo<$DecksTable, Deck> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DecksTable(this.attachedDatabase, [this._alias]);
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
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, parentId, deleted, version];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'decks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Deck> instance, {
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
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Deck map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Deck(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $DecksTable createAlias(String alias) {
    return $DecksTable(attachedDatabase, alias);
  }
}

class Deck extends DataClass implements Insertable<Deck> {
  final String id;

  /// 牌组名（同一父级下唯一）。
  final String name;

  /// 父牌组 id，null 表示顶层牌组（支持嵌套）。
  final String? parentId;

  /// 是否已删除（软删除，便于同步传播删除）。
  final bool deleted;

  /// 同步用：毫秒时间戳，最后写入者胜出。
  final int version;
  const Deck({
    required this.id,
    required this.name,
    this.parentId,
    required this.deleted,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['deleted'] = Variable<bool>(deleted);
    map['version'] = Variable<int>(version);
    return map;
  }

  DecksCompanion toCompanion(bool nullToAbsent) {
    return DecksCompanion(
      id: Value(id),
      name: Value(name),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      deleted: Value(deleted),
      version: Value(version),
    );
  }

  factory Deck.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Deck(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'parentId': serializer.toJson<String?>(parentId),
      'deleted': serializer.toJson<bool>(deleted),
      'version': serializer.toJson<int>(version),
    };
  }

  Deck copyWith({
    String? id,
    String? name,
    Value<String?> parentId = const Value.absent(),
    bool? deleted,
    int? version,
  }) => Deck(
    id: id ?? this.id,
    name: name ?? this.name,
    parentId: parentId.present ? parentId.value : this.parentId,
    deleted: deleted ?? this.deleted,
    version: version ?? this.version,
  );
  Deck copyWithCompanion(DecksCompanion data) {
    return Deck(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Deck(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('deleted: $deleted, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, parentId, deleted, version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Deck &&
          other.id == this.id &&
          other.name == this.name &&
          other.parentId == this.parentId &&
          other.deleted == this.deleted &&
          other.version == this.version);
}

class DecksCompanion extends UpdateCompanion<Deck> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> parentId;
  final Value<bool> deleted;
  final Value<int> version;
  final Value<int> rowid;
  const DecksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DecksCompanion.insert({
    required String id,
    required String name,
    this.parentId = const Value.absent(),
    this.deleted = const Value.absent(),
    required int version,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       version = Value(version);
  static Insertable<Deck> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? parentId,
    Expression<bool>? deleted,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (deleted != null) 'deleted': deleted,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DecksCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? parentId,
    Value<bool>? deleted,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return DecksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      deleted: deleted ?? this.deleted,
      version: version ?? this.version,
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
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DecksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('deleted: $deleted, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteTypesTable extends NoteTypes
    with TableInfo<$NoteTypesTable, NoteType> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTypesTable(this.attachedDatabase, [this._alias]);
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
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldsMeta = const VerificationMeta('fields');
  @override
  late final GeneratedColumn<String> fields = GeneratedColumn<String>(
    'fields',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templatesMeta = const VerificationMeta(
    'templates',
  );
  @override
  late final GeneratedColumn<String> templates = GeneratedColumn<String>(
    'templates',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cssMeta = const VerificationMeta('css');
  @override
  late final GeneratedColumn<String> css = GeneratedColumn<String>(
    'css',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isClozeMeta = const VerificationMeta(
    'isCloze',
  );
  @override
  late final GeneratedColumn<bool> isCloze = GeneratedColumn<bool>(
    'is_cloze',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_cloze" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    fields,
    templates,
    css,
    isCloze,
    deleted,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteType> instance, {
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
    if (data.containsKey('fields')) {
      context.handle(
        _fieldsMeta,
        fields.isAcceptableOrUnknown(data['fields']!, _fieldsMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldsMeta);
    }
    if (data.containsKey('templates')) {
      context.handle(
        _templatesMeta,
        templates.isAcceptableOrUnknown(data['templates']!, _templatesMeta),
      );
    } else if (isInserting) {
      context.missing(_templatesMeta);
    }
    if (data.containsKey('css')) {
      context.handle(
        _cssMeta,
        css.isAcceptableOrUnknown(data['css']!, _cssMeta),
      );
    }
    if (data.containsKey('is_cloze')) {
      context.handle(
        _isClozeMeta,
        isCloze.isAcceptableOrUnknown(data['is_cloze']!, _isClozeMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteType map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteType(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      fields: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fields'],
      )!,
      templates: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}templates'],
      )!,
      css: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}css'],
      )!,
      isCloze: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_cloze'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $NoteTypesTable createAlias(String alias) {
    return $NoteTypesTable(attachedDatabase, alias);
  }
}

class NoteType extends DataClass implements Insertable<NoteType> {
  final String id;
  final String name;

  /// 字段名列表，JSON 数组字符串，如 ["正面","背面"]。
  final String fields;

  /// 卡片模板列表，JSON 数组字符串。普通类型一项 {q,a}；完形填空按 c1..cn。
  final String templates;

  /// 卡片展示 CSS。
  final String css;

  /// 是否为完形填空类型。
  final bool isCloze;
  final bool deleted;
  final int version;
  const NoteType({
    required this.id,
    required this.name,
    required this.fields,
    required this.templates,
    required this.css,
    required this.isCloze,
    required this.deleted,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['fields'] = Variable<String>(fields);
    map['templates'] = Variable<String>(templates);
    map['css'] = Variable<String>(css);
    map['is_cloze'] = Variable<bool>(isCloze);
    map['deleted'] = Variable<bool>(deleted);
    map['version'] = Variable<int>(version);
    return map;
  }

  NoteTypesCompanion toCompanion(bool nullToAbsent) {
    return NoteTypesCompanion(
      id: Value(id),
      name: Value(name),
      fields: Value(fields),
      templates: Value(templates),
      css: Value(css),
      isCloze: Value(isCloze),
      deleted: Value(deleted),
      version: Value(version),
    );
  }

  factory NoteType.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteType(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      fields: serializer.fromJson<String>(json['fields']),
      templates: serializer.fromJson<String>(json['templates']),
      css: serializer.fromJson<String>(json['css']),
      isCloze: serializer.fromJson<bool>(json['isCloze']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'fields': serializer.toJson<String>(fields),
      'templates': serializer.toJson<String>(templates),
      'css': serializer.toJson<String>(css),
      'isCloze': serializer.toJson<bool>(isCloze),
      'deleted': serializer.toJson<bool>(deleted),
      'version': serializer.toJson<int>(version),
    };
  }

  NoteType copyWith({
    String? id,
    String? name,
    String? fields,
    String? templates,
    String? css,
    bool? isCloze,
    bool? deleted,
    int? version,
  }) => NoteType(
    id: id ?? this.id,
    name: name ?? this.name,
    fields: fields ?? this.fields,
    templates: templates ?? this.templates,
    css: css ?? this.css,
    isCloze: isCloze ?? this.isCloze,
    deleted: deleted ?? this.deleted,
    version: version ?? this.version,
  );
  NoteType copyWithCompanion(NoteTypesCompanion data) {
    return NoteType(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      fields: data.fields.present ? data.fields.value : this.fields,
      templates: data.templates.present ? data.templates.value : this.templates,
      css: data.css.present ? data.css.value : this.css,
      isCloze: data.isCloze.present ? data.isCloze.value : this.isCloze,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteType(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('fields: $fields, ')
          ..write('templates: $templates, ')
          ..write('css: $css, ')
          ..write('isCloze: $isCloze, ')
          ..write('deleted: $deleted, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, fields, templates, css, isCloze, deleted, version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteType &&
          other.id == this.id &&
          other.name == this.name &&
          other.fields == this.fields &&
          other.templates == this.templates &&
          other.css == this.css &&
          other.isCloze == this.isCloze &&
          other.deleted == this.deleted &&
          other.version == this.version);
}

class NoteTypesCompanion extends UpdateCompanion<NoteType> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> fields;
  final Value<String> templates;
  final Value<String> css;
  final Value<bool> isCloze;
  final Value<bool> deleted;
  final Value<int> version;
  final Value<int> rowid;
  const NoteTypesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.fields = const Value.absent(),
    this.templates = const Value.absent(),
    this.css = const Value.absent(),
    this.isCloze = const Value.absent(),
    this.deleted = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteTypesCompanion.insert({
    required String id,
    required String name,
    required String fields,
    required String templates,
    this.css = const Value.absent(),
    this.isCloze = const Value.absent(),
    this.deleted = const Value.absent(),
    required int version,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       fields = Value(fields),
       templates = Value(templates),
       version = Value(version);
  static Insertable<NoteType> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? fields,
    Expression<String>? templates,
    Expression<String>? css,
    Expression<bool>? isCloze,
    Expression<bool>? deleted,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (fields != null) 'fields': fields,
      if (templates != null) 'templates': templates,
      if (css != null) 'css': css,
      if (isCloze != null) 'is_cloze': isCloze,
      if (deleted != null) 'deleted': deleted,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteTypesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? fields,
    Value<String>? templates,
    Value<String>? css,
    Value<bool>? isCloze,
    Value<bool>? deleted,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return NoteTypesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      fields: fields ?? this.fields,
      templates: templates ?? this.templates,
      css: css ?? this.css,
      isCloze: isCloze ?? this.isCloze,
      deleted: deleted ?? this.deleted,
      version: version ?? this.version,
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
    if (fields.present) {
      map['fields'] = Variable<String>(fields.value);
    }
    if (templates.present) {
      map['templates'] = Variable<String>(templates.value);
    }
    if (css.present) {
      map['css'] = Variable<String>(css.value);
    }
    if (isCloze.present) {
      map['is_cloze'] = Variable<bool>(isCloze.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTypesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('fields: $fields, ')
          ..write('templates: $templates, ')
          ..write('css: $css, ')
          ..write('isCloze: $isCloze, ')
          ..write('deleted: $deleted, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteTypeIdMeta = const VerificationMeta(
    'noteTypeId',
  );
  @override
  late final GeneratedColumn<String> noteTypeId = GeneratedColumn<String>(
    'note_type_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldsMeta = const VerificationMeta('fields');
  @override
  late final GeneratedColumn<String> fields = GeneratedColumn<String>(
    'fields',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _guidMeta = const VerificationMeta('guid');
  @override
  late final GeneratedColumn<String> guid = GeneratedColumn<String>(
    'guid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteTypeId,
    fields,
    tags,
    guid,
    deleted,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('note_type_id')) {
      context.handle(
        _noteTypeIdMeta,
        noteTypeId.isAcceptableOrUnknown(
          data['note_type_id']!,
          _noteTypeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_noteTypeIdMeta);
    }
    if (data.containsKey('fields')) {
      context.handle(
        _fieldsMeta,
        fields.isAcceptableOrUnknown(data['fields']!, _fieldsMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldsMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('guid')) {
      context.handle(
        _guidMeta,
        guid.isAcceptableOrUnknown(data['guid']!, _guidMeta),
      );
    } else if (isInserting) {
      context.missing(_guidMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      noteTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_type_id'],
      )!,
      fields: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fields'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      guid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guid'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final String id;
  final String noteTypeId;

  /// 字段值列表，JSON 数组字符串，顺序与 NoteTypes.fields 对齐。
  final String fields;

  /// 标签，空格分隔字符串。
  final String tags;

  /// 全局唯一 id（导入/去重用，仿 Anki guid）。
  final String guid;
  final bool deleted;
  final int version;
  const Note({
    required this.id,
    required this.noteTypeId,
    required this.fields,
    required this.tags,
    required this.guid,
    required this.deleted,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['note_type_id'] = Variable<String>(noteTypeId);
    map['fields'] = Variable<String>(fields);
    map['tags'] = Variable<String>(tags);
    map['guid'] = Variable<String>(guid);
    map['deleted'] = Variable<bool>(deleted);
    map['version'] = Variable<int>(version);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      noteTypeId: Value(noteTypeId),
      fields: Value(fields),
      tags: Value(tags),
      guid: Value(guid),
      deleted: Value(deleted),
      version: Value(version),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<String>(json['id']),
      noteTypeId: serializer.fromJson<String>(json['noteTypeId']),
      fields: serializer.fromJson<String>(json['fields']),
      tags: serializer.fromJson<String>(json['tags']),
      guid: serializer.fromJson<String>(json['guid']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteTypeId': serializer.toJson<String>(noteTypeId),
      'fields': serializer.toJson<String>(fields),
      'tags': serializer.toJson<String>(tags),
      'guid': serializer.toJson<String>(guid),
      'deleted': serializer.toJson<bool>(deleted),
      'version': serializer.toJson<int>(version),
    };
  }

  Note copyWith({
    String? id,
    String? noteTypeId,
    String? fields,
    String? tags,
    String? guid,
    bool? deleted,
    int? version,
  }) => Note(
    id: id ?? this.id,
    noteTypeId: noteTypeId ?? this.noteTypeId,
    fields: fields ?? this.fields,
    tags: tags ?? this.tags,
    guid: guid ?? this.guid,
    deleted: deleted ?? this.deleted,
    version: version ?? this.version,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      noteTypeId: data.noteTypeId.present
          ? data.noteTypeId.value
          : this.noteTypeId,
      fields: data.fields.present ? data.fields.value : this.fields,
      tags: data.tags.present ? data.tags.value : this.tags,
      guid: data.guid.present ? data.guid.value : this.guid,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('noteTypeId: $noteTypeId, ')
          ..write('fields: $fields, ')
          ..write('tags: $tags, ')
          ..write('guid: $guid, ')
          ..write('deleted: $deleted, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, noteTypeId, fields, tags, guid, deleted, version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.noteTypeId == this.noteTypeId &&
          other.fields == this.fields &&
          other.tags == this.tags &&
          other.guid == this.guid &&
          other.deleted == this.deleted &&
          other.version == this.version);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<String> id;
  final Value<String> noteTypeId;
  final Value<String> fields;
  final Value<String> tags;
  final Value<String> guid;
  final Value<bool> deleted;
  final Value<int> version;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.noteTypeId = const Value.absent(),
    this.fields = const Value.absent(),
    this.tags = const Value.absent(),
    this.guid = const Value.absent(),
    this.deleted = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String id,
    required String noteTypeId,
    required String fields,
    this.tags = const Value.absent(),
    required String guid,
    this.deleted = const Value.absent(),
    required int version,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       noteTypeId = Value(noteTypeId),
       fields = Value(fields),
       guid = Value(guid),
       version = Value(version);
  static Insertable<Note> custom({
    Expression<String>? id,
    Expression<String>? noteTypeId,
    Expression<String>? fields,
    Expression<String>? tags,
    Expression<String>? guid,
    Expression<bool>? deleted,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteTypeId != null) 'note_type_id': noteTypeId,
      if (fields != null) 'fields': fields,
      if (tags != null) 'tags': tags,
      if (guid != null) 'guid': guid,
      if (deleted != null) 'deleted': deleted,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? id,
    Value<String>? noteTypeId,
    Value<String>? fields,
    Value<String>? tags,
    Value<String>? guid,
    Value<bool>? deleted,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      noteTypeId: noteTypeId ?? this.noteTypeId,
      fields: fields ?? this.fields,
      tags: tags ?? this.tags,
      guid: guid ?? this.guid,
      deleted: deleted ?? this.deleted,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteTypeId.present) {
      map['note_type_id'] = Variable<String>(noteTypeId.value);
    }
    if (fields.present) {
      map['fields'] = Variable<String>(fields.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (guid.present) {
      map['guid'] = Variable<String>(guid.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('noteTypeId: $noteTypeId, ')
          ..write('fields: $fields, ')
          ..write('tags: $tags, ')
          ..write('guid: $guid, ')
          ..write('deleted: $deleted, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CardsTable extends Cards with TableInfo<$CardsTable, Card> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<String> deckId = GeneratedColumn<String>(
    'deck_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateIndexMeta = const VerificationMeta(
    'templateIndex',
  );
  @override
  late final GeneratedColumn<int> templateIndex = GeneratedColumn<int>(
    'template_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _queueMeta = const VerificationMeta('queue');
  @override
  late final GeneratedColumn<int> queue = GeneratedColumn<int>(
    'queue',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dueMeta = const VerificationMeta('due');
  @override
  late final GeneratedColumn<int> due = GeneratedColumn<int>(
    'due',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stabilityMeta = const VerificationMeta(
    'stability',
  );
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
    'stability',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<double> difficulty = GeneratedColumn<double>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _stabilityFastMeta = const VerificationMeta(
    'stabilityFast',
  );
  @override
  late final GeneratedColumn<double> stabilityFast = GeneratedColumn<double>(
    'stability_fast',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReviewMeta = const VerificationMeta(
    'lastReview',
  );
  @override
  late final GeneratedColumn<int> lastReview = GeneratedColumn<int>(
    'last_review',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    deckId,
    templateIndex,
    queue,
    due,
    stability,
    difficulty,
    stabilityFast,
    reps,
    lapses,
    lastReview,
    deleted,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<Card> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deckIdMeta);
    }
    if (data.containsKey('template_index')) {
      context.handle(
        _templateIndexMeta,
        templateIndex.isAcceptableOrUnknown(
          data['template_index']!,
          _templateIndexMeta,
        ),
      );
    }
    if (data.containsKey('queue')) {
      context.handle(
        _queueMeta,
        queue.isAcceptableOrUnknown(data['queue']!, _queueMeta),
      );
    }
    if (data.containsKey('due')) {
      context.handle(
        _dueMeta,
        due.isAcceptableOrUnknown(data['due']!, _dueMeta),
      );
    }
    if (data.containsKey('stability')) {
      context.handle(
        _stabilityMeta,
        stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta),
      );
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    }
    if (data.containsKey('stability_fast')) {
      context.handle(
        _stabilityFastMeta,
        stabilityFast.isAcceptableOrUnknown(
          data['stability_fast']!,
          _stabilityFastMeta,
        ),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    }
    if (data.containsKey('last_review')) {
      context.handle(
        _lastReviewMeta,
        lastReview.isAcceptableOrUnknown(data['last_review']!, _lastReviewMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Card map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Card(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deck_id'],
      )!,
      templateIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}template_index'],
      )!,
      queue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}queue'],
      )!,
      due: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due'],
      )!,
      stability: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stability'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}difficulty'],
      )!,
      stabilityFast: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stability_fast'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      lapses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses'],
      )!,
      lastReview: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_review'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }
}

class Card extends DataClass implements Insertable<Card> {
  final String id;
  final String noteId;

  /// 卡片所属牌组。
  final String deckId;

  /// 该笔记生成的第几张卡片（模板下标）。
  final int templateIndex;
  final int queue;

  /// 到期时间（毫秒时间戳）。新卡=尚未安排。
  final int due;
  final double stability;
  final double difficulty;
  final double stabilityFast;
  final int reps;
  final int lapses;

  /// 上次复习时间（毫秒时间戳），0 表示从未复习。
  final int lastReview;
  final bool deleted;
  final int version;
  const Card({
    required this.id,
    required this.noteId,
    required this.deckId,
    required this.templateIndex,
    required this.queue,
    required this.due,
    required this.stability,
    required this.difficulty,
    required this.stabilityFast,
    required this.reps,
    required this.lapses,
    required this.lastReview,
    required this.deleted,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['note_id'] = Variable<String>(noteId);
    map['deck_id'] = Variable<String>(deckId);
    map['template_index'] = Variable<int>(templateIndex);
    map['queue'] = Variable<int>(queue);
    map['due'] = Variable<int>(due);
    map['stability'] = Variable<double>(stability);
    map['difficulty'] = Variable<double>(difficulty);
    map['stability_fast'] = Variable<double>(stabilityFast);
    map['reps'] = Variable<int>(reps);
    map['lapses'] = Variable<int>(lapses);
    map['last_review'] = Variable<int>(lastReview);
    map['deleted'] = Variable<bool>(deleted);
    map['version'] = Variable<int>(version);
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      id: Value(id),
      noteId: Value(noteId),
      deckId: Value(deckId),
      templateIndex: Value(templateIndex),
      queue: Value(queue),
      due: Value(due),
      stability: Value(stability),
      difficulty: Value(difficulty),
      stabilityFast: Value(stabilityFast),
      reps: Value(reps),
      lapses: Value(lapses),
      lastReview: Value(lastReview),
      deleted: Value(deleted),
      version: Value(version),
    );
  }

  factory Card.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Card(
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String>(json['noteId']),
      deckId: serializer.fromJson<String>(json['deckId']),
      templateIndex: serializer.fromJson<int>(json['templateIndex']),
      queue: serializer.fromJson<int>(json['queue']),
      due: serializer.fromJson<int>(json['due']),
      stability: serializer.fromJson<double>(json['stability']),
      difficulty: serializer.fromJson<double>(json['difficulty']),
      stabilityFast: serializer.fromJson<double>(json['stabilityFast']),
      reps: serializer.fromJson<int>(json['reps']),
      lapses: serializer.fromJson<int>(json['lapses']),
      lastReview: serializer.fromJson<int>(json['lastReview']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String>(noteId),
      'deckId': serializer.toJson<String>(deckId),
      'templateIndex': serializer.toJson<int>(templateIndex),
      'queue': serializer.toJson<int>(queue),
      'due': serializer.toJson<int>(due),
      'stability': serializer.toJson<double>(stability),
      'difficulty': serializer.toJson<double>(difficulty),
      'stabilityFast': serializer.toJson<double>(stabilityFast),
      'reps': serializer.toJson<int>(reps),
      'lapses': serializer.toJson<int>(lapses),
      'lastReview': serializer.toJson<int>(lastReview),
      'deleted': serializer.toJson<bool>(deleted),
      'version': serializer.toJson<int>(version),
    };
  }

  Card copyWith({
    String? id,
    String? noteId,
    String? deckId,
    int? templateIndex,
    int? queue,
    int? due,
    double? stability,
    double? difficulty,
    double? stabilityFast,
    int? reps,
    int? lapses,
    int? lastReview,
    bool? deleted,
    int? version,
  }) => Card(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    deckId: deckId ?? this.deckId,
    templateIndex: templateIndex ?? this.templateIndex,
    queue: queue ?? this.queue,
    due: due ?? this.due,
    stability: stability ?? this.stability,
    difficulty: difficulty ?? this.difficulty,
    stabilityFast: stabilityFast ?? this.stabilityFast,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    lastReview: lastReview ?? this.lastReview,
    deleted: deleted ?? this.deleted,
    version: version ?? this.version,
  );
  Card copyWithCompanion(CardsCompanion data) {
    return Card(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      templateIndex: data.templateIndex.present
          ? data.templateIndex.value
          : this.templateIndex,
      queue: data.queue.present ? data.queue.value : this.queue,
      due: data.due.present ? data.due.value : this.due,
      stability: data.stability.present ? data.stability.value : this.stability,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      stabilityFast: data.stabilityFast.present
          ? data.stabilityFast.value
          : this.stabilityFast,
      reps: data.reps.present ? data.reps.value : this.reps,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      lastReview: data.lastReview.present
          ? data.lastReview.value
          : this.lastReview,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Card(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('deckId: $deckId, ')
          ..write('templateIndex: $templateIndex, ')
          ..write('queue: $queue, ')
          ..write('due: $due, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('stabilityFast: $stabilityFast, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('lastReview: $lastReview, ')
          ..write('deleted: $deleted, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    noteId,
    deckId,
    templateIndex,
    queue,
    due,
    stability,
    difficulty,
    stabilityFast,
    reps,
    lapses,
    lastReview,
    deleted,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Card &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.deckId == this.deckId &&
          other.templateIndex == this.templateIndex &&
          other.queue == this.queue &&
          other.due == this.due &&
          other.stability == this.stability &&
          other.difficulty == this.difficulty &&
          other.stabilityFast == this.stabilityFast &&
          other.reps == this.reps &&
          other.lapses == this.lapses &&
          other.lastReview == this.lastReview &&
          other.deleted == this.deleted &&
          other.version == this.version);
}

class CardsCompanion extends UpdateCompanion<Card> {
  final Value<String> id;
  final Value<String> noteId;
  final Value<String> deckId;
  final Value<int> templateIndex;
  final Value<int> queue;
  final Value<int> due;
  final Value<double> stability;
  final Value<double> difficulty;
  final Value<double> stabilityFast;
  final Value<int> reps;
  final Value<int> lapses;
  final Value<int> lastReview;
  final Value<bool> deleted;
  final Value<int> version;
  final Value<int> rowid;
  const CardsCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.deckId = const Value.absent(),
    this.templateIndex = const Value.absent(),
    this.queue = const Value.absent(),
    this.due = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.stabilityFast = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.lastReview = const Value.absent(),
    this.deleted = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardsCompanion.insert({
    required String id,
    required String noteId,
    required String deckId,
    this.templateIndex = const Value.absent(),
    this.queue = const Value.absent(),
    this.due = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.stabilityFast = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.lastReview = const Value.absent(),
    this.deleted = const Value.absent(),
    required int version,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       noteId = Value(noteId),
       deckId = Value(deckId),
       version = Value(version);
  static Insertable<Card> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<String>? deckId,
    Expression<int>? templateIndex,
    Expression<int>? queue,
    Expression<int>? due,
    Expression<double>? stability,
    Expression<double>? difficulty,
    Expression<double>? stabilityFast,
    Expression<int>? reps,
    Expression<int>? lapses,
    Expression<int>? lastReview,
    Expression<bool>? deleted,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (deckId != null) 'deck_id': deckId,
      if (templateIndex != null) 'template_index': templateIndex,
      if (queue != null) 'queue': queue,
      if (due != null) 'due': due,
      if (stability != null) 'stability': stability,
      if (difficulty != null) 'difficulty': difficulty,
      if (stabilityFast != null) 'stability_fast': stabilityFast,
      if (reps != null) 'reps': reps,
      if (lapses != null) 'lapses': lapses,
      if (lastReview != null) 'last_review': lastReview,
      if (deleted != null) 'deleted': deleted,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardsCompanion copyWith({
    Value<String>? id,
    Value<String>? noteId,
    Value<String>? deckId,
    Value<int>? templateIndex,
    Value<int>? queue,
    Value<int>? due,
    Value<double>? stability,
    Value<double>? difficulty,
    Value<double>? stabilityFast,
    Value<int>? reps,
    Value<int>? lapses,
    Value<int>? lastReview,
    Value<bool>? deleted,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return CardsCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      deckId: deckId ?? this.deckId,
      templateIndex: templateIndex ?? this.templateIndex,
      queue: queue ?? this.queue,
      due: due ?? this.due,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      stabilityFast: stabilityFast ?? this.stabilityFast,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      lastReview: lastReview ?? this.lastReview,
      deleted: deleted ?? this.deleted,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (deckId.present) {
      map['deck_id'] = Variable<String>(deckId.value);
    }
    if (templateIndex.present) {
      map['template_index'] = Variable<int>(templateIndex.value);
    }
    if (queue.present) {
      map['queue'] = Variable<int>(queue.value);
    }
    if (due.present) {
      map['due'] = Variable<int>(due.value);
    }
    if (stability.present) {
      map['stability'] = Variable<double>(stability.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<double>(difficulty.value);
    }
    if (stabilityFast.present) {
      map['stability_fast'] = Variable<double>(stabilityFast.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (lastReview.present) {
      map['last_review'] = Variable<int>(lastReview.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('deckId: $deckId, ')
          ..write('templateIndex: $templateIndex, ')
          ..write('queue: $queue, ')
          ..write('due: $due, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('stabilityFast: $stabilityFast, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('lastReview: $lastReview, ')
          ..write('deleted: $deleted, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewLogsTable extends ReviewLogs
    with TableInfo<$ReviewLogsTable, ReviewLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewedAtMeta = const VerificationMeta(
    'reviewedAt',
  );
  @override
  late final GeneratedColumn<int> reviewedAt = GeneratedColumn<int>(
    'reviewed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _takenMsMeta = const VerificationMeta(
    'takenMs',
  );
  @override
  late final GeneratedColumn<int> takenMs = GeneratedColumn<int>(
    'taken_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _intervalBeforeMeta = const VerificationMeta(
    'intervalBefore',
  );
  @override
  late final GeneratedColumn<double> intervalBefore = GeneratedColumn<double>(
    'interval_before',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _intervalAfterMeta = const VerificationMeta(
    'intervalAfter',
  );
  @override
  late final GeneratedColumn<double> intervalAfter = GeneratedColumn<double>(
    'interval_after',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _undoneMeta = const VerificationMeta('undone');
  @override
  late final GeneratedColumn<bool> undone = GeneratedColumn<bool>(
    'undone',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("undone" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardId,
    rating,
    reviewedAt,
    takenMs,
    intervalBefore,
    intervalAfter,
    undone,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
        _reviewedAtMeta,
        reviewedAt.isAcceptableOrUnknown(data['reviewed_at']!, _reviewedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewedAtMeta);
    }
    if (data.containsKey('taken_ms')) {
      context.handle(
        _takenMsMeta,
        takenMs.isAcceptableOrUnknown(data['taken_ms']!, _takenMsMeta),
      );
    }
    if (data.containsKey('interval_before')) {
      context.handle(
        _intervalBeforeMeta,
        intervalBefore.isAcceptableOrUnknown(
          data['interval_before']!,
          _intervalBeforeMeta,
        ),
      );
    }
    if (data.containsKey('interval_after')) {
      context.handle(
        _intervalAfterMeta,
        intervalAfter.isAcceptableOrUnknown(
          data['interval_after']!,
          _intervalAfterMeta,
        ),
      );
    }
    if (data.containsKey('undone')) {
      context.handle(
        _undoneMeta,
        undone.isAcceptableOrUnknown(data['undone']!, _undoneMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_id'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      )!,
      reviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reviewed_at'],
      )!,
      takenMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}taken_ms'],
      )!,
      intervalBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}interval_before'],
      )!,
      intervalAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}interval_after'],
      )!,
      undone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}undone'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $ReviewLogsTable createAlias(String alias) {
    return $ReviewLogsTable(attachedDatabase, alias);
  }
}

class ReviewLog extends DataClass implements Insertable<ReviewLog> {
  final String id;
  final String cardId;

  /// 评分 1..4。
  final int rating;

  /// 复习时间（毫秒时间戳）。
  final int reviewedAt;

  /// 作答耗时（毫秒）。
  final int takenMs;

  /// 复习前的间隔（天）。
  final double intervalBefore;

  /// 复习后的间隔（天）。
  final double intervalAfter;

  /// 是否被撤销（撤销的复习不计入统计）。
  final bool undone;
  final int version;
  const ReviewLog({
    required this.id,
    required this.cardId,
    required this.rating,
    required this.reviewedAt,
    required this.takenMs,
    required this.intervalBefore,
    required this.intervalAfter,
    required this.undone,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['card_id'] = Variable<String>(cardId);
    map['rating'] = Variable<int>(rating);
    map['reviewed_at'] = Variable<int>(reviewedAt);
    map['taken_ms'] = Variable<int>(takenMs);
    map['interval_before'] = Variable<double>(intervalBefore);
    map['interval_after'] = Variable<double>(intervalAfter);
    map['undone'] = Variable<bool>(undone);
    map['version'] = Variable<int>(version);
    return map;
  }

  ReviewLogsCompanion toCompanion(bool nullToAbsent) {
    return ReviewLogsCompanion(
      id: Value(id),
      cardId: Value(cardId),
      rating: Value(rating),
      reviewedAt: Value(reviewedAt),
      takenMs: Value(takenMs),
      intervalBefore: Value(intervalBefore),
      intervalAfter: Value(intervalAfter),
      undone: Value(undone),
      version: Value(version),
    );
  }

  factory ReviewLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewLog(
      id: serializer.fromJson<String>(json['id']),
      cardId: serializer.fromJson<String>(json['cardId']),
      rating: serializer.fromJson<int>(json['rating']),
      reviewedAt: serializer.fromJson<int>(json['reviewedAt']),
      takenMs: serializer.fromJson<int>(json['takenMs']),
      intervalBefore: serializer.fromJson<double>(json['intervalBefore']),
      intervalAfter: serializer.fromJson<double>(json['intervalAfter']),
      undone: serializer.fromJson<bool>(json['undone']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cardId': serializer.toJson<String>(cardId),
      'rating': serializer.toJson<int>(rating),
      'reviewedAt': serializer.toJson<int>(reviewedAt),
      'takenMs': serializer.toJson<int>(takenMs),
      'intervalBefore': serializer.toJson<double>(intervalBefore),
      'intervalAfter': serializer.toJson<double>(intervalAfter),
      'undone': serializer.toJson<bool>(undone),
      'version': serializer.toJson<int>(version),
    };
  }

  ReviewLog copyWith({
    String? id,
    String? cardId,
    int? rating,
    int? reviewedAt,
    int? takenMs,
    double? intervalBefore,
    double? intervalAfter,
    bool? undone,
    int? version,
  }) => ReviewLog(
    id: id ?? this.id,
    cardId: cardId ?? this.cardId,
    rating: rating ?? this.rating,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    takenMs: takenMs ?? this.takenMs,
    intervalBefore: intervalBefore ?? this.intervalBefore,
    intervalAfter: intervalAfter ?? this.intervalAfter,
    undone: undone ?? this.undone,
    version: version ?? this.version,
  );
  ReviewLog copyWithCompanion(ReviewLogsCompanion data) {
    return ReviewLog(
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      rating: data.rating.present ? data.rating.value : this.rating,
      reviewedAt: data.reviewedAt.present
          ? data.reviewedAt.value
          : this.reviewedAt,
      takenMs: data.takenMs.present ? data.takenMs.value : this.takenMs,
      intervalBefore: data.intervalBefore.present
          ? data.intervalBefore.value
          : this.intervalBefore,
      intervalAfter: data.intervalAfter.present
          ? data.intervalAfter.value
          : this.intervalAfter,
      undone: data.undone.present ? data.undone.value : this.undone,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLog(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('rating: $rating, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('takenMs: $takenMs, ')
          ..write('intervalBefore: $intervalBefore, ')
          ..write('intervalAfter: $intervalAfter, ')
          ..write('undone: $undone, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cardId,
    rating,
    reviewedAt,
    takenMs,
    intervalBefore,
    intervalAfter,
    undone,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewLog &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.rating == this.rating &&
          other.reviewedAt == this.reviewedAt &&
          other.takenMs == this.takenMs &&
          other.intervalBefore == this.intervalBefore &&
          other.intervalAfter == this.intervalAfter &&
          other.undone == this.undone &&
          other.version == this.version);
}

class ReviewLogsCompanion extends UpdateCompanion<ReviewLog> {
  final Value<String> id;
  final Value<String> cardId;
  final Value<int> rating;
  final Value<int> reviewedAt;
  final Value<int> takenMs;
  final Value<double> intervalBefore;
  final Value<double> intervalAfter;
  final Value<bool> undone;
  final Value<int> version;
  final Value<int> rowid;
  const ReviewLogsCompanion({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.rating = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.takenMs = const Value.absent(),
    this.intervalBefore = const Value.absent(),
    this.intervalAfter = const Value.absent(),
    this.undone = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewLogsCompanion.insert({
    required String id,
    required String cardId,
    required int rating,
    required int reviewedAt,
    this.takenMs = const Value.absent(),
    this.intervalBefore = const Value.absent(),
    this.intervalAfter = const Value.absent(),
    this.undone = const Value.absent(),
    required int version,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cardId = Value(cardId),
       rating = Value(rating),
       reviewedAt = Value(reviewedAt),
       version = Value(version);
  static Insertable<ReviewLog> custom({
    Expression<String>? id,
    Expression<String>? cardId,
    Expression<int>? rating,
    Expression<int>? reviewedAt,
    Expression<int>? takenMs,
    Expression<double>? intervalBefore,
    Expression<double>? intervalAfter,
    Expression<bool>? undone,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (rating != null) 'rating': rating,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (takenMs != null) 'taken_ms': takenMs,
      if (intervalBefore != null) 'interval_before': intervalBefore,
      if (intervalAfter != null) 'interval_after': intervalAfter,
      if (undone != null) 'undone': undone,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? cardId,
    Value<int>? rating,
    Value<int>? reviewedAt,
    Value<int>? takenMs,
    Value<double>? intervalBefore,
    Value<double>? intervalAfter,
    Value<bool>? undone,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return ReviewLogsCompanion(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      rating: rating ?? this.rating,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      takenMs: takenMs ?? this.takenMs,
      intervalBefore: intervalBefore ?? this.intervalBefore,
      intervalAfter: intervalAfter ?? this.intervalAfter,
      undone: undone ?? this.undone,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<int>(reviewedAt.value);
    }
    if (takenMs.present) {
      map['taken_ms'] = Variable<int>(takenMs.value);
    }
    if (intervalBefore.present) {
      map['interval_before'] = Variable<double>(intervalBefore.value);
    }
    if (intervalAfter.present) {
      map['interval_after'] = Variable<double>(intervalAfter.value);
    }
    if (undone.present) {
      map['undone'] = Variable<bool>(undone.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogsCompanion(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('rating: $rating, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('takenMs: $takenMs, ')
          ..write('intervalBefore: $intervalBefore, ')
          ..write('intervalAfter: $intervalAfter, ')
          ..write('undone: $undone, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CollectionConfigsTable extends CollectionConfigs
    with TableInfo<$CollectionConfigsTable, CollectionConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, version];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collection_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CollectionConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionConfig(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $CollectionConfigsTable createAlias(String alias) {
    return $CollectionConfigsTable(attachedDatabase, alias);
  }
}

class CollectionConfig extends DataClass
    implements Insertable<CollectionConfig> {
  final String key;
  final String value;
  final int version;
  const CollectionConfig({
    required this.key,
    required this.value,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['version'] = Variable<int>(version);
    return map;
  }

  CollectionConfigsCompanion toCompanion(bool nullToAbsent) {
    return CollectionConfigsCompanion(
      key: Value(key),
      value: Value(value),
      version: Value(version),
    );
  }

  factory CollectionConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionConfig(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'version': serializer.toJson<int>(version),
    };
  }

  CollectionConfig copyWith({String? key, String? value, int? version}) =>
      CollectionConfig(
        key: key ?? this.key,
        value: value ?? this.value,
        version: version ?? this.version,
      );
  CollectionConfig copyWithCompanion(CollectionConfigsCompanion data) {
    return CollectionConfig(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionConfig(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionConfig &&
          other.key == this.key &&
          other.value == this.value &&
          other.version == this.version);
}

class CollectionConfigsCompanion extends UpdateCompanion<CollectionConfig> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> version;
  final Value<int> rowid;
  const CollectionConfigsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollectionConfigsCompanion.insert({
    required String key,
    required String value,
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<CollectionConfig> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollectionConfigsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return CollectionConfigsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      version: version ?? this.version,
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
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionConfigsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$OnestepDb extends GeneratedDatabase {
  _$OnestepDb(QueryExecutor e) : super(e);
  $OnestepDbManager get managers => $OnestepDbManager(this);
  late final $DecksTable decks = $DecksTable(this);
  late final $NoteTypesTable noteTypes = $NoteTypesTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $ReviewLogsTable reviewLogs = $ReviewLogsTable(this);
  late final $CollectionConfigsTable collectionConfigs =
      $CollectionConfigsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    decks,
    noteTypes,
    notes,
    cards,
    reviewLogs,
    collectionConfigs,
  ];
}

typedef $$DecksTableCreateCompanionBuilder = DecksCompanion Function({
  required String id,
  required String name,
  Value<String?> parentId,
  Value<bool> deleted,
  required int version,
  Value<int> rowid,
});
typedef $$DecksTableUpdateCompanionBuilder = DecksCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> parentId,
  Value<bool> deleted,
  Value<int> version,
  Value<int> rowid,
});

class $$DecksTableFilterComposer extends Composer<_$OnestepDb, $DecksTable> {
  $$DecksTableFilterComposer({
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

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DecksTableOrderingComposer extends Composer<_$OnestepDb, $DecksTable> {
  $$DecksTableOrderingComposer({
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

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DecksTableAnnotationComposer
    extends Composer<_$OnestepDb, $DecksTable> {
  $$DecksTableAnnotationComposer({
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

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$DecksTableTableManager
    extends
        RootTableManager<
          _$OnestepDb,
          $DecksTable,
          Deck,
          $$DecksTableFilterComposer,
          $$DecksTableOrderingComposer,
          $$DecksTableAnnotationComposer,
          $$DecksTableCreateCompanionBuilder,
          $$DecksTableUpdateCompanionBuilder,
          (Deck, BaseReferences<_$OnestepDb, $DecksTable, Deck>),
          Deck,
          PrefetchHooks Function()
        > {
  $$DecksTableTableManager(_$OnestepDb db, $DecksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DecksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DecksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DecksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DecksCompanion(
                id: id,
                name: name,
                parentId: parentId,
                deleted: deleted,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> parentId = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required int version,
                Value<int> rowid = const Value.absent(),
              }) => DecksCompanion.insert(
                id: id,
                name: name,
                parentId: parentId,
                deleted: deleted,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DecksTable, Deck>(table),
                  BaseReferences<_$OnestepDb, $DecksTable, Deck>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DecksTableProcessedTableManager =
    ProcessedTableManager<
      _$OnestepDb,
      $DecksTable,
      Deck,
      $$DecksTableFilterComposer,
      $$DecksTableOrderingComposer,
      $$DecksTableAnnotationComposer,
      $$DecksTableCreateCompanionBuilder,
      $$DecksTableUpdateCompanionBuilder,
      (Deck, BaseReferences<_$OnestepDb, $DecksTable, Deck>),
      Deck,
      PrefetchHooks Function()
    >;
typedef $$NoteTypesTableCreateCompanionBuilder = NoteTypesCompanion Function({
  required String id,
  required String name,
  required String fields,
  required String templates,
  Value<String> css,
  Value<bool> isCloze,
  Value<bool> deleted,
  required int version,
  Value<int> rowid,
});
typedef $$NoteTypesTableUpdateCompanionBuilder = NoteTypesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> fields,
  Value<String> templates,
  Value<String> css,
  Value<bool> isCloze,
  Value<bool> deleted,
  Value<int> version,
  Value<int> rowid,
});

class $$NoteTypesTableFilterComposer
    extends Composer<_$OnestepDb, $NoteTypesTable> {
  $$NoteTypesTableFilterComposer({
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

  ColumnFilters<String> get fields => $composableBuilder(
    column: $table.fields,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templates => $composableBuilder(
    column: $table.templates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get css => $composableBuilder(
    column: $table.css,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCloze => $composableBuilder(
    column: $table.isCloze,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteTypesTableOrderingComposer
    extends Composer<_$OnestepDb, $NoteTypesTable> {
  $$NoteTypesTableOrderingComposer({
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

  ColumnOrderings<String> get fields => $composableBuilder(
    column: $table.fields,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templates => $composableBuilder(
    column: $table.templates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get css => $composableBuilder(
    column: $table.css,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCloze => $composableBuilder(
    column: $table.isCloze,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteTypesTableAnnotationComposer
    extends Composer<_$OnestepDb, $NoteTypesTable> {
  $$NoteTypesTableAnnotationComposer({
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

  GeneratedColumn<String> get fields =>
      $composableBuilder(column: $table.fields, builder: (column) => column);

  GeneratedColumn<String> get templates =>
      $composableBuilder(column: $table.templates, builder: (column) => column);

  GeneratedColumn<String> get css =>
      $composableBuilder(column: $table.css, builder: (column) => column);

  GeneratedColumn<bool> get isCloze =>
      $composableBuilder(column: $table.isCloze, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$NoteTypesTableTableManager
    extends
        RootTableManager<
          _$OnestepDb,
          $NoteTypesTable,
          NoteType,
          $$NoteTypesTableFilterComposer,
          $$NoteTypesTableOrderingComposer,
          $$NoteTypesTableAnnotationComposer,
          $$NoteTypesTableCreateCompanionBuilder,
          $$NoteTypesTableUpdateCompanionBuilder,
          (NoteType, BaseReferences<_$OnestepDb, $NoteTypesTable, NoteType>),
          NoteType,
          PrefetchHooks Function()
        > {
  $$NoteTypesTableTableManager(_$OnestepDb db, $NoteTypesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> fields = const Value.absent(),
                Value<String> templates = const Value.absent(),
                Value<String> css = const Value.absent(),
                Value<bool> isCloze = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteTypesCompanion(
                id: id,
                name: name,
                fields: fields,
                templates: templates,
                css: css,
                isCloze: isCloze,
                deleted: deleted,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String fields,
                required String templates,
                Value<String> css = const Value.absent(),
                Value<bool> isCloze = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required int version,
                Value<int> rowid = const Value.absent(),
              }) => NoteTypesCompanion.insert(
                id: id,
                name: name,
                fields: fields,
                templates: templates,
                css: css,
                isCloze: isCloze,
                deleted: deleted,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteTypesTable, NoteType>(table),
                  BaseReferences<_$OnestepDb, $NoteTypesTable, NoteType>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteTypesTableProcessedTableManager =
    ProcessedTableManager<
      _$OnestepDb,
      $NoteTypesTable,
      NoteType,
      $$NoteTypesTableFilterComposer,
      $$NoteTypesTableOrderingComposer,
      $$NoteTypesTableAnnotationComposer,
      $$NoteTypesTableCreateCompanionBuilder,
      $$NoteTypesTableUpdateCompanionBuilder,
      (NoteType, BaseReferences<_$OnestepDb, $NoteTypesTable, NoteType>),
      NoteType,
      PrefetchHooks Function()
    >;
typedef $$NotesTableCreateCompanionBuilder = NotesCompanion Function({
  required String id,
  required String noteTypeId,
  required String fields,
  Value<String> tags,
  required String guid,
  Value<bool> deleted,
  required int version,
  Value<int> rowid,
});
typedef $$NotesTableUpdateCompanionBuilder = NotesCompanion Function({
  Value<String> id,
  Value<String> noteTypeId,
  Value<String> fields,
  Value<String> tags,
  Value<String> guid,
  Value<bool> deleted,
  Value<int> version,
  Value<int> rowid,
});

class $$NotesTableFilterComposer extends Composer<_$OnestepDb, $NotesTable> {
  $$NotesTableFilterComposer({
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

  ColumnFilters<String> get noteTypeId => $composableBuilder(
    column: $table.noteTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fields => $composableBuilder(
    column: $table.fields,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guid => $composableBuilder(
    column: $table.guid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer extends Composer<_$OnestepDb, $NotesTable> {
  $$NotesTableOrderingComposer({
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

  ColumnOrderings<String> get noteTypeId => $composableBuilder(
    column: $table.noteTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fields => $composableBuilder(
    column: $table.fields,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guid => $composableBuilder(
    column: $table.guid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$OnestepDb, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get noteTypeId => $composableBuilder(
    column: $table.noteTypeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fields =>
      $composableBuilder(column: $table.fields, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get guid =>
      $composableBuilder(column: $table.guid, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$OnestepDb,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, BaseReferences<_$OnestepDb, $NotesTable, Note>),
          Note,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$OnestepDb db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> noteTypeId = const Value.absent(),
                Value<String> fields = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> guid = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                noteTypeId: noteTypeId,
                fields: fields,
                tags: tags,
                guid: guid,
                deleted: deleted,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String noteTypeId,
                required String fields,
                Value<String> tags = const Value.absent(),
                required String guid,
                Value<bool> deleted = const Value.absent(),
                required int version,
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                noteTypeId: noteTypeId,
                fields: fields,
                tags: tags,
                guid: guid,
                deleted: deleted,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotesTable, Note>(table),
                  BaseReferences<_$OnestepDb, $NotesTable, Note>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$OnestepDb,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, BaseReferences<_$OnestepDb, $NotesTable, Note>),
      Note,
      PrefetchHooks Function()
    >;
typedef $$CardsTableCreateCompanionBuilder = CardsCompanion Function({
  required String id,
  required String noteId,
  required String deckId,
  Value<int> templateIndex,
  Value<int> queue,
  Value<int> due,
  Value<double> stability,
  Value<double> difficulty,
  Value<double> stabilityFast,
  Value<int> reps,
  Value<int> lapses,
  Value<int> lastReview,
  Value<bool> deleted,
  required int version,
  Value<int> rowid,
});
typedef $$CardsTableUpdateCompanionBuilder = CardsCompanion Function({
  Value<String> id,
  Value<String> noteId,
  Value<String> deckId,
  Value<int> templateIndex,
  Value<int> queue,
  Value<int> due,
  Value<double> stability,
  Value<double> difficulty,
  Value<double> stabilityFast,
  Value<int> reps,
  Value<int> lapses,
  Value<int> lastReview,
  Value<bool> deleted,
  Value<int> version,
  Value<int> rowid,
});

class $$CardsTableFilterComposer extends Composer<_$OnestepDb, $CardsTable> {
  $$CardsTableFilterComposer({
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

  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deckId => $composableBuilder(
    column: $table.deckId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get templateIndex => $composableBuilder(
    column: $table.templateIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get queue => $composableBuilder(
    column: $table.queue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stabilityFast => $composableBuilder(
    column: $table.stabilityFast,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CardsTableOrderingComposer extends Composer<_$OnestepDb, $CardsTable> {
  $$CardsTableOrderingComposer({
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

  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deckId => $composableBuilder(
    column: $table.deckId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get templateIndex => $composableBuilder(
    column: $table.templateIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get queue => $composableBuilder(
    column: $table.queue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stabilityFast => $composableBuilder(
    column: $table.stabilityFast,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardsTableAnnotationComposer
    extends Composer<_$OnestepDb, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get deckId =>
      $composableBuilder(column: $table.deckId, builder: (column) => column);

  GeneratedColumn<int> get templateIndex => $composableBuilder(
    column: $table.templateIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get queue =>
      $composableBuilder(column: $table.queue, builder: (column) => column);

  GeneratedColumn<int> get due =>
      $composableBuilder(column: $table.due, builder: (column) => column);

  GeneratedColumn<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => column);

  GeneratedColumn<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<double> get stabilityFast => $composableBuilder(
    column: $table.stabilityFast,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumn<int> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$OnestepDb,
          $CardsTable,
          Card,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (Card, BaseReferences<_$OnestepDb, $CardsTable, Card>),
          Card,
          PrefetchHooks Function()
        > {
  $$CardsTableTableManager(_$OnestepDb db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<String> deckId = const Value.absent(),
                Value<int> templateIndex = const Value.absent(),
                Value<int> queue = const Value.absent(),
                Value<int> due = const Value.absent(),
                Value<double> stability = const Value.absent(),
                Value<double> difficulty = const Value.absent(),
                Value<double> stabilityFast = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<int> lastReview = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion(
                id: id,
                noteId: noteId,
                deckId: deckId,
                templateIndex: templateIndex,
                queue: queue,
                due: due,
                stability: stability,
                difficulty: difficulty,
                stabilityFast: stabilityFast,
                reps: reps,
                lapses: lapses,
                lastReview: lastReview,
                deleted: deleted,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String noteId,
                required String deckId,
                Value<int> templateIndex = const Value.absent(),
                Value<int> queue = const Value.absent(),
                Value<int> due = const Value.absent(),
                Value<double> stability = const Value.absent(),
                Value<double> difficulty = const Value.absent(),
                Value<double> stabilityFast = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<int> lastReview = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required int version,
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion.insert(
                id: id,
                noteId: noteId,
                deckId: deckId,
                templateIndex: templateIndex,
                queue: queue,
                due: due,
                stability: stability,
                difficulty: difficulty,
                stabilityFast: stabilityFast,
                reps: reps,
                lapses: lapses,
                lastReview: lastReview,
                deleted: deleted,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CardsTable, Card>(table),
                  BaseReferences<_$OnestepDb, $CardsTable, Card>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$OnestepDb,
      $CardsTable,
      Card,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (Card, BaseReferences<_$OnestepDb, $CardsTable, Card>),
      Card,
      PrefetchHooks Function()
    >;
typedef $$ReviewLogsTableCreateCompanionBuilder = ReviewLogsCompanion Function({
  required String id,
  required String cardId,
  required int rating,
  required int reviewedAt,
  Value<int> takenMs,
  Value<double> intervalBefore,
  Value<double> intervalAfter,
  Value<bool> undone,
  required int version,
  Value<int> rowid,
});
typedef $$ReviewLogsTableUpdateCompanionBuilder = ReviewLogsCompanion Function({
  Value<String> id,
  Value<String> cardId,
  Value<int> rating,
  Value<int> reviewedAt,
  Value<int> takenMs,
  Value<double> intervalBefore,
  Value<double> intervalAfter,
  Value<bool> undone,
  Value<int> version,
  Value<int> rowid,
});

class $$ReviewLogsTableFilterComposer
    extends Composer<_$OnestepDb, $ReviewLogsTable> {
  $$ReviewLogsTableFilterComposer({
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

  ColumnFilters<String> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get takenMs => $composableBuilder(
    column: $table.takenMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get intervalBefore => $composableBuilder(
    column: $table.intervalBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get intervalAfter => $composableBuilder(
    column: $table.intervalAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get undone => $composableBuilder(
    column: $table.undone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReviewLogsTableOrderingComposer
    extends Composer<_$OnestepDb, $ReviewLogsTable> {
  $$ReviewLogsTableOrderingComposer({
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

  ColumnOrderings<String> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get takenMs => $composableBuilder(
    column: $table.takenMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get intervalBefore => $composableBuilder(
    column: $table.intervalBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get intervalAfter => $composableBuilder(
    column: $table.intervalAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get undone => $composableBuilder(
    column: $table.undone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReviewLogsTableAnnotationComposer
    extends Composer<_$OnestepDb, $ReviewLogsTable> {
  $$ReviewLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cardId =>
      $composableBuilder(column: $table.cardId, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get takenMs =>
      $composableBuilder(column: $table.takenMs, builder: (column) => column);

  GeneratedColumn<double> get intervalBefore => $composableBuilder(
    column: $table.intervalBefore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get intervalAfter => $composableBuilder(
    column: $table.intervalAfter,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get undone =>
      $composableBuilder(column: $table.undone, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$ReviewLogsTableTableManager
    extends
        RootTableManager<
          _$OnestepDb,
          $ReviewLogsTable,
          ReviewLog,
          $$ReviewLogsTableFilterComposer,
          $$ReviewLogsTableOrderingComposer,
          $$ReviewLogsTableAnnotationComposer,
          $$ReviewLogsTableCreateCompanionBuilder,
          $$ReviewLogsTableUpdateCompanionBuilder,
          (ReviewLog, BaseReferences<_$OnestepDb, $ReviewLogsTable, ReviewLog>),
          ReviewLog,
          PrefetchHooks Function()
        > {
  $$ReviewLogsTableTableManager(_$OnestepDb db, $ReviewLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> cardId = const Value.absent(),
                Value<int> rating = const Value.absent(),
                Value<int> reviewedAt = const Value.absent(),
                Value<int> takenMs = const Value.absent(),
                Value<double> intervalBefore = const Value.absent(),
                Value<double> intervalAfter = const Value.absent(),
                Value<bool> undone = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewLogsCompanion(
                id: id,
                cardId: cardId,
                rating: rating,
                reviewedAt: reviewedAt,
                takenMs: takenMs,
                intervalBefore: intervalBefore,
                intervalAfter: intervalAfter,
                undone: undone,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String cardId,
                required int rating,
                required int reviewedAt,
                Value<int> takenMs = const Value.absent(),
                Value<double> intervalBefore = const Value.absent(),
                Value<double> intervalAfter = const Value.absent(),
                Value<bool> undone = const Value.absent(),
                required int version,
                Value<int> rowid = const Value.absent(),
              }) => ReviewLogsCompanion.insert(
                id: id,
                cardId: cardId,
                rating: rating,
                reviewedAt: reviewedAt,
                takenMs: takenMs,
                intervalBefore: intervalBefore,
                intervalAfter: intervalAfter,
                undone: undone,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReviewLogsTable, ReviewLog>(table),
                  BaseReferences<_$OnestepDb, $ReviewLogsTable, ReviewLog>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReviewLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$OnestepDb,
      $ReviewLogsTable,
      ReviewLog,
      $$ReviewLogsTableFilterComposer,
      $$ReviewLogsTableOrderingComposer,
      $$ReviewLogsTableAnnotationComposer,
      $$ReviewLogsTableCreateCompanionBuilder,
      $$ReviewLogsTableUpdateCompanionBuilder,
      (ReviewLog, BaseReferences<_$OnestepDb, $ReviewLogsTable, ReviewLog>),
      ReviewLog,
      PrefetchHooks Function()
    >;
typedef $$CollectionConfigsTableCreateCompanionBuilder =
    CollectionConfigsCompanion Function({
      required String key,
      required String value,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$CollectionConfigsTableUpdateCompanionBuilder =
    CollectionConfigsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> version,
      Value<int> rowid,
    });

class $$CollectionConfigsTableFilterComposer
    extends Composer<_$OnestepDb, $CollectionConfigsTable> {
  $$CollectionConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CollectionConfigsTableOrderingComposer
    extends Composer<_$OnestepDb, $CollectionConfigsTable> {
  $$CollectionConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionConfigsTableAnnotationComposer
    extends Composer<_$OnestepDb, $CollectionConfigsTable> {
  $$CollectionConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$CollectionConfigsTableTableManager
    extends
        RootTableManager<
          _$OnestepDb,
          $CollectionConfigsTable,
          CollectionConfig,
          $$CollectionConfigsTableFilterComposer,
          $$CollectionConfigsTableOrderingComposer,
          $$CollectionConfigsTableAnnotationComposer,
          $$CollectionConfigsTableCreateCompanionBuilder,
          $$CollectionConfigsTableUpdateCompanionBuilder,
          (
            CollectionConfig,
            BaseReferences<
              _$OnestepDb,
              $CollectionConfigsTable,
              CollectionConfig
            >,
          ),
          CollectionConfig,
          PrefetchHooks Function()
        > {
  $$CollectionConfigsTableTableManager(
    _$OnestepDb db,
    $CollectionConfigsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionConfigsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionConfigsCompanion(
                key: key,
                value: value,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionConfigsCompanion.insert(
                key: key,
                value: value,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CollectionConfigsTable, CollectionConfig>(table),
                  BaseReferences<
                    _$OnestepDb,
                    $CollectionConfigsTable,
                    CollectionConfig
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CollectionConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$OnestepDb,
      $CollectionConfigsTable,
      CollectionConfig,
      $$CollectionConfigsTableFilterComposer,
      $$CollectionConfigsTableOrderingComposer,
      $$CollectionConfigsTableAnnotationComposer,
      $$CollectionConfigsTableCreateCompanionBuilder,
      $$CollectionConfigsTableUpdateCompanionBuilder,
      (
        CollectionConfig,
        BaseReferences<_$OnestepDb, $CollectionConfigsTable, CollectionConfig>,
      ),
      CollectionConfig,
      PrefetchHooks Function()
    >;

class $OnestepDbManager {
  final _$OnestepDb _db;
  $OnestepDbManager(this._db);
  $$DecksTableTableManager get decks =>
      $$DecksTableTableManager(_db, _db.decks);
  $$NoteTypesTableTableManager get noteTypes =>
      $$NoteTypesTableTableManager(_db, _db.noteTypes);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
  $$ReviewLogsTableTableManager get reviewLogs =>
      $$ReviewLogsTableTableManager(_db, _db.reviewLogs);
  $$CollectionConfigsTableTableManager get collectionConfigs =>
      $$CollectionConfigsTableTableManager(_db, _db.collectionConfigs);
}

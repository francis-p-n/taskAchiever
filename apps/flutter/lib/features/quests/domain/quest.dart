import 'package:isar/isar.dart';

part 'quest.g.dart';

@collection
class Quest {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  String? remoteId;

  String? title;
  
  String? description;
  
  int? difficulty;
  
  String? category;

  DateTime? syncedAt;
  
  DateTime? updatedAt;
}

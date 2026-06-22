import { Isar } from 'isar';
import { Part } from 'isar';

// Run `flutter pub run build_runner build` to generate this file
// part 'quest.g.dart';

// @Collection()
export class Quest {
  // id = Isar.autoIncrement; // you can also use id = null to auto increment

  // @Index(type: IndexType.value)
  id?: number;

  remoteId?: string; // String ID from backend

  title?: string;
  
  description?: string;
  
  difficulty?: number;
  
  category?: string;

  // @Index()
  syncedAt?: Date;
  
  updatedAt?: Date;
}

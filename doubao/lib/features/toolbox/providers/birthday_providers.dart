import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/birthday_repository.dart';

final birthdayRepositoryProvider = Provider((ref) => BirthdayRepository(AppDatabase.instance));
final birthdaysProvider = StreamProvider((ref) => ref.watch(birthdayRepositoryProvider).watchAll());

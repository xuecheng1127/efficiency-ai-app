import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/location_reminder_repository.dart';

final locationReminderRepoProvider = Provider((ref) => LocationReminderRepository(AppDatabase.instance));
final locationRemindersProvider = StreamProvider((ref) => ref.watch(locationReminderRepoProvider).watchAll());

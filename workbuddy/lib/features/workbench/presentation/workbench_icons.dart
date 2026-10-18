import 'package:flutter/material.dart';

import '../domain/workbench_module.dart';

/// 模块 → 图标。
///
/// 单独放一个文件：`IconData` 属于表现层，不能进 domain；而放在任一页面里，
/// 另一个页面为了复用它就得 import 一个无关页面（还会形成循环 import）。
IconData workbenchModuleIcon(WorkbenchModule module) => switch (module) {
  WorkbenchModule.tasks => Icons.checklist_rounded,
  WorkbenchModule.diary => Icons.auto_stories_outlined,
};

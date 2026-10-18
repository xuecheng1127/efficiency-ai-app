import '../../alarm/domain/alarm_repository.dart';
import '../domain/task_instance.dart';
import '../domain/task_repository.dart';

/// 「删除任务」的编排（应用层）：**撤闹钟 → 销模板 → 销实例**。
///
/// 为什么需要一个单独的编排类，而不是在页面里连调两个仓库：
/// 1. 顺序有意义 —— 先撤铃声再销数据。反过来的话，一旦撤铃声失败，
///    用户会得到一个「列表里没有了、但明天早上照响」的幽灵闹钟，那是最坏的结果；
/// 2. 任何入口（列表、将来的详情页/长按菜单）只要走这里，就不会漏掉某一步；
/// 3. 可单测：两个仓库都是接口，测试里用内存实现即可，不需要起 UI。
class DeleteTask {
  const DeleteTask(this._tasks, this._alarms);

  final TaskRepository _tasks;
  final AlarmRepository _alarms;

  /// 删除一条任务所代表的**整个模板**（而不是只有今天那一条实例）。
  ///
  /// 若闹钟撤销抛错，直接终止：宁可不删，也不要留下还会响的闹钟。
  Future<void> call(TaskInstance instance) async {
    await _alarms.cancelForTask(instance.templateId);
    await _tasks.deleteTemplate(instance.templateId);
  }
}

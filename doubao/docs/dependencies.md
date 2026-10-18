# 依赖与解析版本（docs/dependencies.md）

> 本文件记录 T01 数据模型任务（Isar→Drift）的依赖变更与 **Drift 实际解析版本**。
> 所有版本以工程 `pubspec.lock` 实测为准（解析时间：T01 任务完成时）。

## 一、Drift 实际解析版本（规格 §八 #5 要求）

| 包 | 解析版本 | 角色 |
|---|---|---|
| **drift** | **2.35.2** | 主依赖：ORM + 查询构建 + 表定义 |
| **drift_dev** | **2.35.1** | dev 依赖：代码生成器（build_runner 插件） |
| sqlite3 | 3.7.1 | 传递依赖：SQLite 绑定 |
| **sqlite3_flutter_libs** | **0.5.42** | 主依赖：内置原生 sqlite3 库 |

## 二、配套生成链（为避开 analyzer 7.x 兼容坑整链升级）

| 包 | 解析版本 | 角色 |
|---|---|---|
| build_runner | 2.16.2 | 代码生成总入口 |
| freezed | 4.0.2 | 不可变状态类生成（dev） |
| freezed_annotation | 3.1.0 | freezed 注解 |
| json_serializable | 6.14.1 | JSON 序列化生成（dev） |
| json_annotation | 4.12.0 | JSON 注解 |
| analyzer | 14.5.0 | 静态分析（传递） |
| source_gen | 4.3.1 | 代码生成基座（传递） |
| build | 4.0.11 | 构建管线（传递） |

## 三、未变更的关键依赖

| 包 | 解析版本 | 说明 |
|---|---|---|
| flutter_riverpod | 2.6.1 | 状态管理（T01 不升 Riverpod 3，规格 §四约定暂缓） |
| fl_chart | 0.69.2 | 热量进度环（后续模块） |
| flutter_foreground_task | 8.17.0 | 前台计时服务（锁 8.17.0：11.x 需 Dart 3.12+/Kotlin 2.2，与工程 AGP/Kotlin 链冲突） |
| lunar | 1.7.8 | 农历转换（工具箱模块） |
| archive | 3.6.1 | 备份 ZIP（后续模块） |
| path_provider | （跟随 pubspec.lock） | 路径 |

## 四、依赖操作记录（含踩坑）

1. `flutter pub remove isar isar_flutter_libs` 批量移除 **失败**（版本约束冲突 + 参数语法问题）→
   改为**手工编辑 `pubspec.yaml`** 删除 isar 系并替换为 drift 系，一次成功。
2. 无镜像在线 `pub get` 超慢、`--offline` 因缺 drift 包 exit 69 → 配置中国镜像
   （`PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`）。
3. **版本约束坑**：若直接 `add drift` 走旧解析链（freezed 2.5.8 + analyzer 7.7.1 与 Dart 3.13 不兼容，
   build_runner AOT exit 78），必须升级整条生成链（见上表第二节），并使用
   `dart run build_runner build --force-jit`。
4. 规格/用户指令只写了 `add drift sqlite3_flutter_libs`，实际还**必须** `add dev:drift_dev`，
   否则无法生成表代码。
5. pub 缓存路径必须为 ASCII（`F:\develop\pub-cache`），否则 Ninja/CMake 无法在中文路径
   （`C:\Users\<用户名>\...`）下 chdir（构建错误 7，见 README 构建适配清单）。

## 五、遗留待决

- `pubspec.yaml` environment sdk 为 `>=3.3.0 <4.0.0`，与 json_serializable 6.14.1 声明
  `sdk ^3.8.0` 存在理论范围差（当前解析成功、无运行时影响）；如需严格对齐需调整 sdk 下限并重跑 pub get。

## 六、2026-10-16 整改补充（ASCII 路径搬迁后复测）

工程已从 `C:\Users\<用户名>\Doubao\chats\...`（中文路径）搬迁到 `F:\develop\efficiency_app`（纯 ASCII），
Gradle 镜像已配（阿里云三仓 + 腾讯云 Gradle wrapper）。复测结果：

- `flutter build apk --debug` 成功：`√ Built build\app\outputs\flutter-apk\app-debug.apk`（约 173 MB）。
- `flutter analyze`：16 info，0 error。
- **Windows 本地 `flutter test` 无法运行**：sqlite3 3.7.1 的 native assets hook 尝试从 github.com 下载
  `sqlite3.x64.windows.dll` 时 TLS 握手失败（国内网络）。Android 真机通过 `sqlite3_flutter_libs` 打包的
  预编译 `.so` 正常工作；单元测试需在有 github 直连或配代理的环境跑。
- 冷启动 splash 在 vivo V2309A（Impeller/Vulkan）上首次渲染 Surface 为 0，退后台再回前台即正常。
  数据层初始化（Drift `createInBackground` + backfill）在后台 isolate 完成，不受 UI 渲染影响。

## 七、存储约定（T10 补充）

- **本工程所有 Drift `dateTime()` 列统一存 epoch 秒**（约 1.79e9），不是毫秒。
  读取时需 `DateTime.fromMillisecondsSinceEpoch(row * 1000)`，写入时 `.millisecondsSinceEpoch ~/ 1000`。


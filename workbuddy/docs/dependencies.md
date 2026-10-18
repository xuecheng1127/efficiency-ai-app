# 依赖记录（docs/dependencies.md）

> T01 交付要求第 5 项。所有版本为 `flutter pub get` 实际解析结果（2026-10-15），
> 非手写猜测。解析时使用清华镜像（见文末环境说明）。

## 一、直接依赖实际解析版本

### dependencies

| 包 | 解析版本 | 用途 |
|---|---|---|
| flutter_riverpod | 3.4.3 | 状态管理（手写 Provider） |
| freezed_annotation | 3.1.0 | freezed 运行时注解 |
| json_annotation | 4.12.0 | JSON 注解 |
| drift | 2.35.2 | 本地数据库（SQLite） |
| sqlite3_flutter_libs | 0.5.42 | SQLite 原生库 |
| go_router | 17.5.0 | 路由 |
| fl_chart | 1.2.0 | 图表（热量进度环） |
| flutter_animate | 4.5.2 | 动画 |
| path_provider | 2.1.6 | 应用目录 |
| path | 1.9.1 | 路径拼接 |
| intl | 0.20.3 | 日期格式化 |
| lunar | 1.7.8 | 农历转换 |
| cupertino_icons | 1.0.9 | 图标 |

### dev_dependencies

| 包 | 解析版本 | 用途 |
|---|---|---|
| build_runner | 2.16.2 | 代码生成 |
| freezed | 4.0.2 | freezed 生成器 |
| json_serializable | 6.14.1 | JSON 序列化生成器 |
| drift_dev | 2.35.1 | Drift 代码生成器 |
| flutter_lints | 5.0.0 | Lint 规则 |

## 二、版本坑记录（重要，避免重踩）

1. **freezed 与 freezed_annotation 版本号不同步**：freezed 最新 4.0.2，但 freezed_annotation 最新是 **3.1.0（没有 4.x）**。必须 `freezed: ^4.0.0` + `freezed_annotation: ^3.1.0`，两者不能写同一个大版本。
2. **freezed 3.x 与 drift_dev 2.34.6+ 冲突**：freezed 3.x 依赖 analyzer <13，drift_dev 2.34.6+ 依赖 analyzer ≥13，二者无法共存。必须升级 freezed 到 4.x（依赖 analyzer ≥13）。
3. **build_runner AOT 编译失败**：本机 build_runner 默认 AOT 编译报 `Unable to read file program.dill`，需加 `--force-jit` 强制 JIT 编译。

## 三、环境说明（本机特有）

- **pub 镜像**：`flutter-env.ps1` 已设置 `PUB_HOSTED_URL = https://mirrors.tuna.tsinghua.edu.cn/dart-pub`。直连 pub.dev 极慢（首页 6s+），会导致 `flutter pub get` 反复超时中断。
- **git 不在 PowerShell PATH**：flutter 命令需要 git，git.exe 位于 `C:\Users\<用户名>\.workbuddy\binaries\PortableGit\versions\1.3.0\cmd`，需手动加入 PATH。
- **⚠️ 中文用户名路径问题**：本机用户名是中文用户名，导致 `flutter test` / `flutter analyze`（LSP 版）在中文路径下崩溃（`WebSocketException: Invalid WebSocket upgrade request`）。`dart analyze` 正常。**测试需在纯英文路径（如 D:\efficiency_app）下运行。**

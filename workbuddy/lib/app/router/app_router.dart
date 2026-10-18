import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_page.dart';

/// 应用路由：V1.0 以底部导航为主，路由表为后续页面跳转预留。
///
/// 未来扩展：`/diary`、`/diary/:id`、`/workbench/:id` 等。
final appRouter = GoRouter(
  routes: [GoRoute(path: '/', builder: (context, state) => const HomePage())],
);

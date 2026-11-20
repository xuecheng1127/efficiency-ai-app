import 'dart:io';

import 'package:efficiency_app/core/constants/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

/// 版本号只有一个真相源：`pubspec.yaml`。
///
/// 设置页曾经写死「版本 1.0.0」，包发到 1.3.0 后界面还在报 1.0.0，用户反馈
/// 问题时报的版本号是错的。这个测试把 `kAppVersion` 和 pubspec 绑在一起：
/// 谁改了 pubspec 忘了改常量（或反过来），这里立刻红。
void main() {
  test('kAppVersion 与 pubspec.yaml 的 version 一致', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml 里找不到 version 行');
    expect(kAppVersion, match!.group(1));
  });
}

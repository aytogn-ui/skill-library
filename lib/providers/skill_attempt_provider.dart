import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/skill_attempt.dart';

/// スキル試技履歴の管理プロバイダー
/// - 試技の追加（成功/失敗）
/// - 直近 100/50/30 回の成功率計算
class SkillAttemptProvider extends ChangeNotifier {
  late Box<SkillAttempt> _box;

  Future<void> init(Box<SkillAttempt> box) async {
    _box = box;
  }

  /// 指定スキルの全試技を新しい順で返す
  List<SkillAttempt> getAttempts(String skillId) {
    final list = _box.values
        .where((a) => a.skillId == skillId)
        .toList();
    list.sort((a, b) => b.attemptAt.compareTo(a.attemptAt));
    return list;
  }

  /// 試技を追加（成功/失敗）
  Future<void> addAttempt({
    required String skillId,
    required bool isSuccess,
    String? routineId,
  }) async {
    final attempt = SkillAttempt(
      id: const Uuid().v4(),
      skillId: skillId,
      attemptAt: DateTime.now(),
      isSuccess: isSuccess,
      routineId: routineId,
    );
    await _box.put(attempt.id, attempt);
    notifyListeners();
  }

  /// 直近N回の成功率を計算
  /// - 試技数がN未満の場合は null を返す（不足数も返す）
  SuccessRateResult calculateRate(String skillId, int windowSize) {
    final attempts = getAttempts(skillId);
    if (attempts.isEmpty) {
      return SuccessRateResult(
        rate: null,
        totalAttempts: 0,
        windowSize: windowSize,
        neededMore: windowSize,
      );
    }
    if (attempts.length < windowSize) {
      return SuccessRateResult(
        rate: null,
        totalAttempts: attempts.length,
        windowSize: windowSize,
        neededMore: windowSize - attempts.length,
      );
    }
    final recent = attempts.take(windowSize).toList();
    final successes = recent.where((a) => a.isSuccess).length;
    final rate = successes / windowSize * 100;
    return SuccessRateResult(
      rate: rate,
      totalAttempts: attempts.length,
      windowSize: windowSize,
      neededMore: 0,
    );
  }

  /// 直近 100, 50, 30 回の成功率をまとめて返す
  SkillSuccessRates getSuccessRates(String skillId) {
    return SkillSuccessRates(
      rate100: calculateRate(skillId, 100),
      rate50: calculateRate(skillId, 50),
      rate30: calculateRate(skillId, 30),
      totalAttempts: getAttempts(skillId).length,
    );
  }

  /// 試技を削除（IDで指定）
  Future<void> deleteAttempt(String attemptId) async {
    await _box.delete(attemptId);
    notifyListeners();
  }

  /// 指定スキルの試技を全削除
  Future<void> deleteAllAttempts(String skillId) async {
    final keys = _box.values
        .where((a) => a.skillId == skillId)
        .map((a) => a.id)
        .toList();
    for (final k in keys) {
      await _box.delete(k);
    }
    notifyListeners();
  }
}

/// 単一ウィンドウの成功率計算結果
class SuccessRateResult {
  /// null = 試技数不足
  final double? rate;
  final int totalAttempts;
  final int windowSize;
  final int neededMore;

  const SuccessRateResult({
    required this.rate,
    required this.totalAttempts,
    required this.windowSize,
    required this.neededMore,
  });

  bool get hasData => rate != null;

  /// カラー: >90% 緑 / 70-89% 黄 / ≤69% 赤
  static Color rateColor(double rate) {
    if (rate >= 90) return const Color(0xFF4CAF50); // 緑
    if (rate >= 70) return const Color(0xFFFFB300); // 黄
    return const Color(0xFFFF5252); // 赤
  }
}

/// 3ウィンドウ（100/50/30）まとめて返す
class SkillSuccessRates {
  final SuccessRateResult rate100;
  final SuccessRateResult rate50;
  final SuccessRateResult rate30;
  final int totalAttempts;

  const SkillSuccessRates({
    required this.rate100,
    required this.rate50,
    required this.rate30,
    required this.totalAttempts,
  });
}

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/skill_attempt.dart';

/// スキル試技履歴の管理プロバイダー
/// - 試技の追加（成功/失敗）
/// - 直近 100/50/30 回の成功率計算
/// - Skill.successCount / failCount（手動入力）を合算して表示
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
  ///
  /// [manualSuccess] / [manualFail]: Skill.successCount / failCount（編集画面の手動入力値）
  /// これらを仮想の「古い試技」として末尾に追加し、SkillAttempt の試技ログと合算する。
  /// 合算後の合計試技数が windowSize 未満の場合は null を返す。
  SuccessRateResult calculateRate(
    String skillId,
    int windowSize, {
    int manualSuccess = 0,
    int manualFail = 0,
  }) {
    // ① SkillAttempt ログ（新しい順）
    final attempts = getAttempts(skillId);

    // ② 手動入力分を仮想試技リストに変換（成功 → true、失敗 → false）
    final manualSuccessList = List.filled(manualSuccess, true);
    final manualFailList = List.filled(manualFail, false);
    // 手動入力は「古い記録」扱いなので末尾に結合
    final combined = [
      ...attempts.map((a) => a.isSuccess),
      ...manualSuccessList,
      ...manualFailList,
    ];

    final totalCombined = combined.length;

    if (totalCombined == 0) {
      return SuccessRateResult(
        rate: null,
        totalAttempts: 0,
        logAttempts: 0,
        manualSuccess: manualSuccess,
        manualFail: manualFail,
        windowSize: windowSize,
        neededMore: windowSize,
      );
    }
    if (totalCombined < windowSize) {
      return SuccessRateResult(
        rate: null,
        totalAttempts: totalCombined,
        logAttempts: attempts.length,
        manualSuccess: manualSuccess,
        manualFail: manualFail,
        windowSize: windowSize,
        neededMore: windowSize - totalCombined,
      );
    }

    // 直近 windowSize 件で成功率を算出
    final recent = combined.take(windowSize).toList();
    final successes = recent.where((s) => s).length;
    final rate = successes / windowSize * 100;

    return SuccessRateResult(
      rate: rate,
      totalAttempts: totalCombined,
      logAttempts: attempts.length,
      manualSuccess: manualSuccess,
      manualFail: manualFail,
      windowSize: windowSize,
      neededMore: 0,
    );
  }

  /// 直近 100, 50, 30 回の成功率をまとめて返す
  SkillSuccessRates getSuccessRates(
    String skillId, {
    int manualSuccess = 0,
    int manualFail = 0,
  }) {
    final total = getAttempts(skillId).length + manualSuccess + manualFail;
    return SkillSuccessRates(
      rate100: calculateRate(skillId, 100,
          manualSuccess: manualSuccess, manualFail: manualFail),
      rate50: calculateRate(skillId, 50,
          manualSuccess: manualSuccess, manualFail: manualFail),
      rate30: calculateRate(skillId, 30,
          manualSuccess: manualSuccess, manualFail: manualFail),
      totalAttempts: total,
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

  /// SkillAttempt ログ + 手動入力 の合計試技数
  final int totalAttempts;

  /// SkillAttempt ログのみの試技数
  final int logAttempts;

  /// Skill.successCount（手動入力）
  final int manualSuccess;

  /// Skill.failCount（手動入力）
  final int manualFail;

  final int windowSize;
  final int neededMore;

  const SuccessRateResult({
    required this.rate,
    required this.totalAttempts,
    this.logAttempts = 0,
    this.manualSuccess = 0,
    this.manualFail = 0,
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

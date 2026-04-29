import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/constants/colors.dart';
import 'package:harukoto_mobile/core/theme/haru_semantic_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HaruSemanticColors', () {
    test('light palette exposes Sakura Depth semantic colors', () {
      final semantic = HaruSemanticColors.fromBrightness(Brightness.light);

      expect(semantic.primaryPressed, AppColors.primaryPressed);
      expect(semantic.accent, AppColors.accent);
      expect(semantic.onAccent, Colors.white);
      expect(semantic.accentContainer, AppColors.accentContainer);
      expect(semantic.success, AppColors.success(Brightness.light));
      expect(semantic.warning, AppColors.warning(Brightness.light));
      expect(semantic.error, AppColors.error(Brightness.light));
      expect(semantic.tabActive, AppColors.accent);
      expect(semantic.tabInactive, AppColors.tabInactive);
      expect(semantic.surfaceMuted, AppColors.surfaceMuted);
    });

    test('copyWith preserves unspecified tokens', () {
      final semantic = HaruSemanticColors.fromBrightness(Brightness.light);
      final updated = semantic.copyWith(tabActive: Colors.black);

      expect(updated.tabActive, Colors.black);
      expect(updated.primaryPressed, semantic.primaryPressed);
      expect(updated.surfaceMuted, semantic.surfaceMuted);
    });
  });
}

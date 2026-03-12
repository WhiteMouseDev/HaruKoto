import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

InputDecoration loginInputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
        color: AppColors.overlay(0.4), fontSize: 14),
    filled: true,
    fillColor: AppColors.overlay(0.02),
    contentPadding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:
          BorderSide(color: AppColors.overlay(0.15)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:
          BorderSide(color: AppColors.overlay(0.15)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
          color: AppColors.primary, width: 2),
    ),
  );
}

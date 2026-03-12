import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import 'call_analyzing_page.dart';
import 'widgets/call_waveform.dart';

class VoiceCallPage extends StatefulWidget {
  final String? scenarioId;
  final String? characterId;
  final String? characterName;
  final String? avatarUrl;

  const VoiceCallPage({
    super.key,
    this.scenarioId,
    this.characterId,
    this.characterName,
    this.avatarUrl,
  });

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  String _state = 'idle'; // idle, connecting, connected, ending, ended
  int _callDuration = 0;
  bool _isMuted = false;
  bool _showSubtitle = false;
  String? _error;
  Timer? _timer;

  String get _formattedDuration {
    final mins = (_callDuration ~/ 60).toString().padLeft(2, '0');
    final secs = (_callDuration % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _startCall() {
    setState(() {
      _state = 'connecting';
      _error = null;
    });

    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _state = 'connected';
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _callDuration++;
        });
      });
    });
  }

  void _endCall() {
    _timer?.cancel();
    _timer = null;
    setState(() => _state = 'ending');

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CallAnalyzingPage()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.arrowLeft,
                        color: AppColors.onGradientMuted),
                  ),
                  const Spacer(),
                  if (_state == 'connected')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.onGradient.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formattedDuration,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.onGradientMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  const Spacer(),
                  const SizedBox(width: 48), // balance
                ],
              ),
            ),

            const Spacer(),

            // Character name
            Text(
              widget.characterName ?? '하루',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.onGradient,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              _state == 'idle'
                  ? '통화 시작을 눌러주세요'
                  : _state == 'connecting'
                      ? '연결 중...'
                      : _state == 'ending'
                          ? '통화 종료 중...'
                          : '통화 중',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onGradient.withValues(alpha: 0.54),
              ),
            ),
            const SizedBox(height: AppSizes.xl),

            // Waveform / Avatar
            CallWaveformWidget(
              mode: _state == 'connected' ? 'speaking' : 'idle',
              avatarUrl: widget.avatarUrl,
            ),

            const Spacer(),

            // Subtitle overlay
            if (_showSubtitle && _state == 'connected')
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.overlay(0.54),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'こんにちは、今日はいい天気ですね。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onGradient,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Error
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),

            // Controls
            Padding(
              padding: const EdgeInsets.all(AppSizes.xl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute button
                  if (_state == 'connected')
                    _ControlButton(
                      icon: _isMuted ? LucideIcons.micOff : LucideIcons.mic,
                      label: _isMuted ? '음소거 해제' : '음소거',
                      onTap: () => setState(() => _isMuted = !_isMuted),
                      color: AppColors.onGradient.withValues(alpha: 0.24),
                    ),

                  // Call / End button
                  _state == 'idle'
                      ? _ControlButton(
                          icon: LucideIcons.phone,
                          label: '통화 시작',
                          onTap: _startCall,
                          color: const Color(0xFF10B981),
                          size: 64,
                        )
                      : _ControlButton(
                          icon: LucideIcons.phoneOff,
                          label: '통화 종료',
                          onTap: _endCall,
                          color: AppColors.error(Theme.of(context).brightness),
                          size: 64,
                        ),

                  // Subtitle toggle
                  if (_state == 'connected')
                    _ControlButton(
                      icon: LucideIcons.messageSquare,
                      label: '자막',
                      onTap: () =>
                          setState(() => _showSubtitle = !_showSubtitle),
                      color: _showSubtitle
                          ? const Color(0xFF10B981)
                          : AppColors.onGradient.withValues(alpha: 0.24),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.lg),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.onGradient, size: size * 0.4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: AppColors.onGradient.withValues(alpha: 0.6), fontSize: 11),
        ),
      ],
    );
  }
}

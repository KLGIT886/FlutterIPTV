import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/background_test_service.dart';
import '../../../core/utils/throttled_state_mixin.dart'; // ✅ 导入节流 mixin

/// 后台测试进度指示器
class BackgroundTestIndicator extends StatefulWidget {
  final VoidCallback onTap;

  const BackgroundTestIndicator({super.key, required this.onTap});

  @override
  State<BackgroundTestIndicator> createState() =>
      BackgroundTestIndicatorState();
}

class BackgroundTestIndicatorState extends State<BackgroundTestIndicator>
    with ThrottledStateMixin {
  final BackgroundTestService _service = BackgroundTestService();
  late BackgroundTestProgress _progress;

  @override
  void initState() {
    super.initState();
    _progress = _service.currentProgress;
    _service.addListener(_onProgressUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_onProgressUpdate);
    super.dispose();
  }

  void _onProgressUpdate(BackgroundTestProgress progress) {
    if (mounted) {
      throttledSetState(() {
        _progress = progress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 只在运行中或有结果时显示
    if (!_progress.isRunning && !_progress.isComplete) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _progress.isRunning
              ? AppTheme.getPrimaryColor(context).withOpacity(0.2)
              : Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_progress.isRunning) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.getPrimaryColor(context),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_progress.completed}/${_progress.total}',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              const Icon(
                Icons.check_circle_outline,
                size: 16,
                color: Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                '测试完成 (${_progress.unavailable}失效)',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
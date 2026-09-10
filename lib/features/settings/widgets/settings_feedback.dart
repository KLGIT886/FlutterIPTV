import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.successColor,
      duration: const Duration(seconds: 2),
    ),
  );
}

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.errorColor,
      duration: const Duration(seconds: 3),
    ),
  );
}


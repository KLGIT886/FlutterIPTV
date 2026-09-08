import 'package:material_ui/material_ui.dart';

import '../../../core/i18n/app_strings.dart';

/// 播放器"解码 / 显示输出 / 硬解 / D3D11VPP"相关设置项的标签与描述文案。
///
/// 从 `settings_screen.dart` 纯搬移而来：这些方法仅依赖 context 与其参数，
/// 不依赖任何 State 字段，故提为顶层函数，便于该文件瘦身与复用。
/// 纯搬移，未改动任何逻辑与文案。

String getDecodingModeLabel(BuildContext context, String mode) {
  final strings = AppStrings.of(context);
  switch (mode) {
    case 'hardware':
      return strings?.decodingModeHardware ?? 'Hardware';
    case 'software':
      return strings?.decodingModeSoftware ?? 'Software';
    case 'auto':
    default:
      return strings?.decodingModeAuto ?? 'Auto';
  }
}

String getDecodingModeDesc(BuildContext context, String mode) {
  final strings = AppStrings.of(context);
  switch (mode) {
    case 'hardware':
      return strings?.decodingModeHardwareDesc ??
          'Force hardware decoding. May fail on some GPUs.';
    case 'software':
      return strings?.decodingModeSoftwareDesc ??
          'Use CPU decoding for compatibility.';
    case 'auto':
    default:
      return strings?.decodingModeAutoDesc ??
          'Automatically choose the best option. Recommended.';
  }
}

String getVideoOutputLabel(BuildContext context, String mode) {
  final strings = AppStrings.of(context);
  switch (mode) {
    case 'libmpv':
      return strings?.videoOutputLibmpv ?? 'libmpv (Embedded)';
    case 'gpu':
      return strings?.videoOutputGpu ?? 'GPU (External Window)';
    case 'auto':
    default:
      return strings?.videoOutputAuto ?? 'Auto (Embedded)';
  }
}

String getVideoOutputDesc(BuildContext context, String mode) {
  final strings = AppStrings.of(context);
  switch (mode) {
    case 'libmpv':
      return strings?.videoOutputLibmpvDesc ??
          'Use libmpv embedded renderer (recommended).';
    case 'gpu':
      return strings?.videoOutputGpuDesc ??
          'Use GPU output; may open a separate window.';
    case 'auto':
    default:
      return strings?.videoOutputAutoDesc ??
          'Default embedded output (recommended).';
  }
}

String getWindowsHwdecLabel(BuildContext context, String mode) {
  final strings = AppStrings.of(context);
  switch (mode) {
    case 'auto-copy':
      return strings?.windowsHwdecAutoCopy ?? 'Auto (Copy)';
    case 'd3d11va':
      return strings?.windowsHwdecD3d11va ?? 'D3D11VA';
    case 'dxva2':
      return strings?.windowsHwdecDxva2 ?? 'DXVA2';
    case 'auto-safe':
    default:
      return strings?.windowsHwdecAutoSafe ?? 'Auto (Safe)';
  }
}

String getWindowsHwdecDesc(BuildContext context, String mode) {
  final strings = AppStrings.of(context);
  switch (mode) {
    case 'auto-copy':
      return strings?.windowsHwdecAutoCopyDesc ??
          'More compatible, but slower due to copy-back.';
    case 'd3d11va':
      return strings?.windowsHwdecD3d11vaDesc ??
          'Prefer D3D11VA. Can fail on some GPUs.';
    case 'dxva2':
      return strings?.windowsHwdecDxva2Desc ??
          'Prefer DXVA2. Legacy path for older GPUs.';
    case 'auto-safe':
    default:
      return strings?.windowsHwdecAutoSafeDesc ??
          'Recommended. Only use safe hardware decoders.';
  }
}

String getD3d11vppLabel(BuildContext context, String mode) {
  final strings = AppStrings.of(context);
  switch (mode) {
    case 'off':
      return strings?.d3d11vppOff ?? 'Off';
    case 'adaptive':
      return strings?.d3d11vppAdaptive ?? 'Adaptive';
    case 'mocomp':
      return strings?.d3d11vppMocomp ?? 'Motion compensation';
    case 'bob':
    default:
      return strings?.d3d11vppBob ?? 'Bob';
  }
}

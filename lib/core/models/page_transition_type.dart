/// 页面切换动画类型
enum PageTransitionType {
  /// 淡入淡出
  fade,
  
  /// 滑动（从右到左）
  slide,
  
  /// 缩放
  scale,
  
  /// 无动画
  none,
}

/// 页面切换动画类型扩展
extension PageTransitionTypeExtension on PageTransitionType {
  /// 转换为字符串
  String toStr() {
    switch (this) {
      case PageTransitionType.fade:
        return 'fade';
      case PageTransitionType.slide:
        return 'slide';
      case PageTransitionType.scale:
        return 'scale';
      case PageTransitionType.none:
        return 'none';
    }
  }

  /// 从字符串转换
  static PageTransitionType fromStr(String str) {
    switch (str) {
      case 'fade':
        return PageTransitionType.fade;
      case 'slide':
        return PageTransitionType.slide;
      case 'scale':
        return PageTransitionType.scale;
      case 'none':
        return PageTransitionType.none;
      default:
        return PageTransitionType.fade; // 默认淡入淡出
    }
  }
}

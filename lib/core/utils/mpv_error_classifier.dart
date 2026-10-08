/// 判断 mpv 报错是否属于「码流瞬时错误」。
///
/// 这类错误由传输丢包或起播瞬间码流不完整引起（刚加入组播时缺 SPS/PPS、
/// RTP 丢片等），**换成软件解码没有任何帮助**。
///
/// 麻烦在于：它们常常让硬件解码器初始化失败，进而报出含 `decoder` / `hwdec`
/// 字样的错误。如果软件回退逻辑只按关键字匹配，一次起播丢包就会把播放器
/// 永久降级到软解（4K 卡顿 + HLG 色彩异常），且只能重启应用恢复。
///
/// 因此回退判定必须先排除这些错误。播放器与多屏播放器共用同一份判定，
/// 避免两处关键字列表各自漂移。
bool isTransientStreamError(String error) {
  final lower = error.toLowerCase();
  return _transientStreamErrors.any(lower.contains);
}

/// 码流瞬时错误的特征串（小写匹配）
const List<String> _transientStreamErrors = <String>[
  'pps id', // hevc: PPS id out of range
  'sps id',
  'nalu', // Skipping invalid undecodable NALU
  'undecodable',
  'missing picture',
  'corrupt',
  'truncated',
  'no frame',
  'invalid data',
];

/// 判断 mpv 报错是否只是「滤镜/属性配置被拒绝」，而非播放故障。
///
/// 我们会在播放中动态改写 `vf`（去交错候选）、`glsl-shaders` 等属性；当取值
/// 被 mpv 拒绝时（例如语法错误的 lavfi 滤镜），mpv 会抛出错 **error** 事件。
/// 这类错误**不是**播放故障：MpvTuner 自己会逐步尝试候选项并回退到硬件去交错。
///
/// 但播放器层的 error 监听此前会把它当成播放失败 → 触发整路重试（重新 open 流）。
/// 实测在 1080i 的软件滤镜候选中放入一个语法错误的 lavfi 滤镜时复现：正常播放
/// 被打断、流被重连，且滤镜轮换与 A/B 探针因而并发出多个实例，结论不可解读。
///
/// 因此播放器层必须先排除这类错误，交给滤镜层自己的重试/回退处理。
bool isConfigError(String error) {
  final lower = error.toLowerCase();
  return _configErrors.any(lower.contains);
}

/// 滤镜/属性配置类错误的特征串（小写匹配）
const List<String> _configErrors = <String>[
  'error parsing option', // 选项/滤镜参数语法错误
  'option not found', // 例如 'lavfi:yadif=...' 把 yadif 当成 lavfi 的参数名
  'error setting option',
  'no such filter',
  'error creating filters',
  'failed to configure the filter graph',
  'impossible to convert', // 滤镜链像素格式不兼容
  'error reconfiguring',
];

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

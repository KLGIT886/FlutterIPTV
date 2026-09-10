/// DLNA/UPnP 的 SOAP 响应构造与 XML/时长处理工具（纯函数，无状态）。
library;

/// 创建 SOAP 响应
String createSoapResponse(String action, String body,
    {String service = 'AVTransport'}) {
  return '''<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:${action}Response xmlns:u="urn:schemas-upnp-org:service:$service:1">
      $body
    </u:${action}Response>
  </s:Body>
</s:Envelope>''';
}

/// 解码 XML 实体
String decodeXmlEntities(String text) {
  return text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}

/// 转义 XML 特殊字符
String escapeXml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

/// 格式化时长为 HH:MM:SS
String formatDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

/// 解析时长字符串
Duration parseDuration(String str) {
  final parts = str.split(':');
  if (parts.length == 3) {
    return Duration(
      hours: int.tryParse(parts[0]) ?? 0,
      minutes: int.tryParse(parts[1]) ?? 0,
      seconds: int.tryParse(parts[2]) ?? 0,
    );
  }
  return Duration.zero;
}

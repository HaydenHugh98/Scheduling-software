import 'dart:html' as html show window;
import 'notification_service_interface.dart';
import 'notification_service_mobile.dart';
import 'notification_service_web.dart';

NotificationServiceInterface _getNotificationService() {
  // 检测是否在 Web 环境
  try {
    if (html.window.navigator.userAgent != null) {
      return NotificationServiceWeb();
    }
  } catch (_) {
    // 在非 Web 环境，html 不可用，直接返回移动端实现
  }
  return NotificationServiceMobile();
}

// 全局唯一实例
final NotificationServiceInterface notificationService = _getNotificationService();
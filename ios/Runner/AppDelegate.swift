import UIKit
import Flutter
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let center = UNUserNotificationCenter.current()
    center.delegate = self   // 父类已经实现了 UNUserNotificationCenterDelegate，不用再在类声明里写

    center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      if let error = error {
        print("通知权限请求失败: \(error)")
      } else {
        print("通知权限状态: \(granted)")
      }
    }

    // 本地通知其实不需要这句，远程推送才真正用到；留着也不会影响编译
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// iOS 10+ 前台收到通知时会走这个方法（决定前台要不要显示通知）
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // 前台也要显示横幅 + 声音 + 角标
    completionHandler([.banner, .sound, .badge])
    // 老一点写法可以用 [.alert, .sound, .badge]
  }

  /// 用户点击通知 / 在通知上执行 action 时调用
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // 把点击事件交回给 Flutter（包括 flutter_local_notifications 的回调）
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}

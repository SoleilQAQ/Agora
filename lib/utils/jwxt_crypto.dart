import 'dart:convert';

class JwxtCrypto {
  /// 将字符串编码为Base64
  ///
  /// [s] 要编码的字符串
  static String str2base64(String s) {
    final strEncode = base64.encode(utf8.encode(s));
    return strEncode;
  }

  /// 加密算法
  ///
  /// [username] 用户名/学号
  /// [password] 密码
  static String encode({
    required String username,
    required String password,
  }) {
    // 使用 base64 编码用户名和密码
    final encodedUsername = str2base64(username);
    final encodedPassword = str2base64(password);

    // 将用户名和密码用 "%%%" 连接
    final encoded = '$encodedUsername%%%$encodedPassword';

    return encoded;
  }
}

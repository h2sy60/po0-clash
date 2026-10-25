po0-clash v6.4.4：修复 Android 底部导航栏被状态栏安全区撑高、图标与文字位置偏移的问题。

## 本次更新

- 修复 Android 底部导航栏重复应用顶部系统安全区，导致胶囊高度和图标、文字位置偏移的问题
- 保留系统手势区和三键导航区的底部安全距离，五个导航入口的显示和点击区域保持对齐

## 升级说明

- 从旧版 po0-clash 直接覆盖安装，已有配置、节点与加白设置保留；Android 构建号递增，签名及应用 ID 保持一致

## 安装

- Windows：po0-clash-6.4.4-windows-amd64-setup.exe（安装包）或 po0-clash-6.4.4-windows-amd64.zip（免安装）
- Windows 校验：发布页提供 po0-clash-signing.cer 和 po0-clash-6.4.4-windows-amd64-sha256.txt，包内附 WINDOWS-SECURITY.txt
- macOS：curl -fsSL https://raw.githubusercontent.com/yuuuki-creation/po0-clash/main/scripts/install-macos.sh | bash
- Android：po0-clash-6.4.4-android-arm64-v8a.apk（主流机型），另提供 armeabi-v7a 和 x86_64 版本

## 已知限制

- 常驻内存尚未达到三端 100 MB 目标；NL Android 固定测试配置后台约 116 MB PSS，Windows 和 macOS 尚无本轮原生内存实测，实际占用取决于设备、订阅和流量
- 自签名提供完整性与发布者连续性，不会自动获得 Windows 信任，也不保证通过 SmartScreen、智能应用控制或杀毒检测；安装程序不会自动导入根证书或关闭安全策略
- Android 从最近任务划掉客户端可能停止加白调度，再次通过快捷方式启动代理或打开客户端会重新初始化；系统强行停止应用后仍需手动打开
- 「手动节点」配置在每次增删改节点时按模板整体重写，直接编辑这份配置文件的改动不会保留；调整规则请使用「覆写」
- 带端口的订阅地址如果粘贴进「分享链接」，会被当作一个 HTTP 代理节点导入
- ggy 加白链接每次请求都会写入，固定每 11 秒检查；日志里持续出现 evicted 说明白名单在被反复挤占
- 同时使用的网段超过白名单容量时，各设备会互相挤占；与其他代理客户端同时开启系统代理或 TUN 也会互相抢占
- macOS 版本未经 Apple 公证，安装脚本会移除隔离属性；每次更新后首次开启虚拟网卡需重新输入管理员密码

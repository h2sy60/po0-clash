po0-clash v6.4.5：内核升到 FlClash 最新 HEAD，新增 Snell v6 支持；Windows 签名改用本 fork 自己的证书，恢复出包；Android 只编 arm64，安装包大幅瘦身。

## 本次更新

- 内核 Clash.Meta 从 70f0570 升到 FlClash 最新 HEAD 5b453f80，新增 Snell v6 支持（节点写 `version: 6`，`mode` 可选 default / unshaped / unsafe-raw，须与服务器一致；v6 不再支持 tls / http 混淆）；另含约 10 个月上游修复（测速与健康检查、断网重连、WireGuard / Hysteria2 / TUIC 修复、一个 CVE 安全修复）
- Windows 签名改用本 fork 自己的自签名证书（指纹 06:C1:9F:05:D8:31:6A:F2:FF:B5:A9:42:19:D2:66:83:DC:92:56:8A:ED:A0:87:D3:A6:91:73:BD:74:37:53:AB，有效期至 2031-11-18），签名配置补齐，Windows 包恢复出包
- Android 只编 arm64，安装包从 168 MB（三架构）降到 55.4 MB（单个 arm64 APK）；32 位 arm 与 x86_64 机型不再提供安装包

## 升级说明

- 从旧版 po0-clash 直接覆盖安装，已有配置、节点与加白设置保留；Android 构建号递增，签名及应用 ID 保持一致

## 安装

- Windows：po0-clash-6.4.5-windows-amd64-setup.exe（安装包）或 po0-clash-6.4.5-windows-amd64.zip（免安装）
- Windows 校验：发布页提供 po0-clash-signing.cer 和 po0-clash-6.4.5-windows-amd64-sha256.txt，包内附 WINDOWS-SECURITY.txt
- macOS：curl -fsSL https://raw.githubusercontent.com/h2sy60/po0-clash/main/scripts/install-macos.sh | bash
- Android：po0-clash-6.4.5-android-arm64-v8a.apk（仅 arm64 机型）

## 已知限制

- 常驻内存尚未达到三端 100 MB 目标；NL Android 固定测试配置后台约 116 MB PSS，Windows 和 macOS 尚无本轮原生内存实测，实际占用取决于设备、订阅和流量
- 自签名提供完整性与发布者连续性，不会自动获得 Windows 信任，也不保证通过 SmartScreen、智能应用控制或杀毒检测；安装程序不会自动导入根证书或关闭安全策略
- Android 从最近任务划掉客户端可能停止加白调度，再次通过快捷方式启动代理或打开客户端会重新初始化；系统强行停止应用后仍需手动打开
- 「手动节点」配置在每次增删改节点时按模板整体重写，直接编辑这份配置文件的改动不会保留；调整规则请使用「覆写」
- 带端口的订阅地址如果粘贴进「分享链接」，会被当作一个 HTTP 代理节点导入
- ggy 加白链接每次请求都会写入，固定每 11 秒检查；日志里持续出现 evicted 说明白名单在被反复挤占
- 同时使用的网段超过白名单容量时，各设备会互相挤占；与其他代理客户端同时开启系统代理或 TUN 也会互相抢占
- macOS 版本未经 Apple 公证，安装脚本会移除隔离属性；每次更新后首次开启虚拟网卡需重新输入管理员密码

# 项目目标

## 背景

[po0fw](https://github.com/w0ven/po0fw) 通过定时向 po0 官方 IP 直连端点发起
`POST https://124.221.69.228/api/firewall/<token>/add`，把设备当前出口 IP 所在 /24 加入 po0 机器的防火墙白名单。
原项目以脚本 / 代理客户端模块的形式分发，需要用户在每台设备上单独部署。

## 目标

1. **集成**：基于 FlClash 二开，把 po0 自动加白做成内置功能，用户只需在应用内填入 token 即可使用。
2. **常驻**：只要 po0-clash 处于打开状态——无论是否开启代理——都持续执行自动加白。
3. **正确性**：加白请求必须以真实出口 IP 发出，不能被本应用的代理 / TUN 劫持成代理节点的 IP。
4. **交付**：
   - Windows：提供安装包（Inno Setup `.exe`），另附免安装 zip。
   - macOS：使用终端命令一键安装。
   - Android：提供 APK 安装包。
   - iOS：不支持，不做。
   - Linux：不在交付范围内（代码保持可构建即可）。
5. **界面**：三端统一采用苹果官网式的简洁排版，使用中性表面、清晰字体和克制配色，由 Material 组件实现；避免模糊和持续装饰动画（[ADR 0016](adr/0016-material3-performance.md)）。
6. **独立应用**：以 po0-clash 的身份发布，应用 ID、安装标识、进程 / 服务名、数据目录与官方 FlClash 完全不同，
   两者可在同一设备上同时安装、运行；版本号独立，本仓库从 5.0.0 开始（[ADR 0006](adr/0006-standalone-app-identity.md)）。
7. **节点导入**：像 v2rayN 一样直接导入 vmess / vless / trojan / ss / hysteria2 等分享链接，节点统一放进「手动节点」配置，
   可以删除、重命名（[ADR 0015](adr/0015-share-link-nodes.md)）。
8. **工程化**：代码放在独立的 GitHub 仓库，及时推送；仓库包含 `AGENTS.md` 与 `docs/` 等标准流程结构；
   format / analyze / test 在构建 VPS 上执行，全部平台的发版产物由 GitHub Actions 在推送版本标签后构建。

## 非目标

- 不修改 mihomo（`core/Clash.Meta`）内核。
- 不引入自建服务端；加白只调用 po0 官方端点。

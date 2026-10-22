# 分享链接导入节点

把单个节点的分享链接直接导入使用，类似 v2rayN / v2rayNG。设计决定见 [ADR 0015](../adr/0015-share-link-nodes.md)。

## 怎么用

- **添加配置 → 分享链接。** 粘贴一条或多条链接（每行一条），也可以粘贴 base64 订阅内容。
- **扫码。** 添加配置里的「二维码」、手机扫码页、桌面端选择二维码图片都能识别分享链接，识别后自动导入节点。
- **节点页。** 「手动节点」配置卡片的菜单 →「节点」。可以从剪贴板导入、扫码、粘贴导入，点节点或编辑按钮重命名，
  删除按钮删除。

第一次导入时会自动创建「手动节点」配置；之后再导入都追加到这份配置里。如果当前还没有选中任何配置，它会成为当前配置。
切到这份配置后，在代理页的「🚀 默认节点」组里选节点即可。

## 支持的链接

由内核 mihomo 的转换器解析：`vmess`、`vless`（含 reality / xhttp 等参数）、`trojan`、`ss`（含插件）、`ssr`、
`hysteria`、`hysteria2` / `hy2`、`tuic`、`anytls`、`mierus`、`socks` / `socks5`。HTTP 代理链接（`http://`、`https://`）
在分享链接框里可以导入，但单独扫码或从 URL 导入时会被当作订阅地址处理。

## 生成的配置

- 模板：`assets/data/node_profile_template.yaml`。它就是这份配置的分流规则、DNS、嗅探和规则集。
- 节点写进 `proxies`；模板里两个分组都开了 `include-all`，节点会被自动纳入，所以 `__PROXY_NODES__` /
  `__PROXY_PROVIDERS__` 占位符会被直接去掉。没开 `include-all` 的分组会把占位符展开成节点名。
- 每次增删改节点都会按模板重写整个文件。直接编辑配置文件的改动不会保留；要调整规则请用配置的「覆写」。
- 应用的设置（端口、TUN、局域网、日志等级等）照常覆盖模板里对应的项，和其他配置一样。

## 代码位置

| 位置 | 内容 |
|---|---|
| `core/share_links.go` | 内核方法 `convertShareLinks`，调用 mihomo `convert.ConvertsV2Ray` |
| `lib/common/node_profile.dart` | 模板渲染、占位符处理、去重与命名、读取节点、`isShareLinkText` |
| `lib/providers/node_profile.dart` | `nodeProfileProvider`、`nodeProfileNodesProvider`、`NodeProfileAction`（导入 / 重命名 / 删除） |
| `lib/views/profiles/nodes.dart` | 节点页与分享链接输入框 |
| `Config.nodeProfileId` | 「手动节点」配置的 ID |

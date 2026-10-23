# Windows 自签名

po0-clash 使用固定的自签名代码签名证书。公钥保存在 `windows/po0-clash-signing.cer`，私钥、PFX 与密码只保存在
本地被 Git 忽略的 `.signing/windows/` 和 GitHub Actions Secrets 中。不要每次发版重新生成证书。

当前公钥证书的 SHA-256 指纹：

```text
74:2E:DB:4A:67:1D:D5:82:9E:E1:53:52:CC:95:B0:88:A6:CC:FB:1A:4B:33:6D:AF:6B:51:3F:ED:8C:21:A2:F9
```

证书有效期为 2026-10-23 至 2031-10-22。签名使用 SHA-256 和 RFC 3161 时间戳。

## 信任边界

自签名提供文件完整性与发布者连续性，**不会自动获得 Windows 信任，也不保证通过 SmartScreen、智能应用控制或杀毒检测**。
微软的智能应用控制会结合信誉与受信任签名作判断；参见
[官方说明](https://learn.microsoft.com/en-us/windows/apps/develop/smart-app-control/overview)。
安装程序不导入根证书、不添加杀毒排除项、不关闭安全策略。公钥证书和 `WINDOWS-SECURITY.txt` 随安装版、便携版提供，
供用户核对；发布页同时提供公钥证书和产物 SHA-256 清单。设备策略拒绝自签名程序时，仍需由设备管理员处理，不能宣称
补上自签名就解决了所有 Windows 拦截。

## 密钥与 CI 配置

首次生成密钥可在 macOS / Linux 上执行：

```bash
bash scripts/windows/create-signing-key.sh
```

脚本在目录已存在时拒绝覆盖。既有密钥应备份到私有的安全位置；不要提交 `.signing/`，也不要把它同步到普通构建工作区。
轮换证书时需明确更新已提交的公钥和本文指纹，并向用户说明变化。

仓库需要两个 Actions Secrets：

| 名称 | 内容 |
|---|---|
| `WINDOWS_SIGNING_PFX_BASE64` | `.signing/windows/code-signing.pfx` 的 Base64 内容 |
| `WINDOWS_SIGNING_PASSWORD` | `.signing/windows/pfx-password` 的内容 |

从本机写入，避免在终端显示密钥或把密码放进命令参数：

```bash
base64 < .signing/windows/code-signing.pfx | tr -d '\n' | gh secret set WINDOWS_SIGNING_PFX_BASE64 --repo yuuuki-creation/po0-clash
tr -d '\r\n' < .signing/windows/pfx-password | gh secret set WINDOWS_SIGNING_PASSWORD --repo yuuuki-creation/po0-clash
```

工作流把 PFX 解码到 runner 临时目录，仅 Windows 打包步骤接收密码。打包脚本核对 PFX 与仓库公钥一致后，
导入当前用户的签名存储；仅在临时 GitHub Actions runner 上为自签名建立临时信任，以完成验签，退出时清除本次导入的证书。
PFX 临时文件由 `always()` 清理步骤删除。产物上传只包含 `dist/`。

## 构建顺序

`dart setup.dart windows --env stable` 调用 `scripts/windows/package.ps1`：

1. 从 PFX 取得证书指纹，写入 `.dart_tool/windows-signing.json`。该文件和签名脚本都是原生构建的缓存输入，证书变化会使缓存失效。
2. Flutter 原生 hook 编译 Go Core，在暂存文件上签名并验证，随后才计算 SHA-256。
3. Rust Helper 内嵌**签名后**的 Core SHA-256；Helper 随后签名。`manifest.json` 使用同一个 Core 校验值。
4. 签名 Flutter 主程序和其他未签名的 PE 库，保留已有有效的第三方签名。已签名 Core / Helper 只验签，避免再次改变 Core 哈希。
5. 核对最终 Core 哈希与清单一致，再生成 ZIP 和 Inno Setup 安装包。Inno Setup 对安装程序和卸载程序都调用相同签名脚本。
6. 导出公钥证书与 SHA-256 清单；任何签名、验签或哈希检查失败都会中止打包。

正式 Windows 打包缺少签名配置会直接失败。`--env dev` / `--env pre` 可以生成未签名的开发包。
Windows 本机构建时，设置 `PO0_WINDOWS_PFX_PATH`、`PO0_WINDOWS_PFX_PASSWORD`；自签名证书需预先在受控构建机上获得信任，
脚本不会自动修改普通电脑的根证书存储。构建机信任不代表用户电脑信任。

## 启动诊断

应用分别显示杀毒检测（225 / 226）、签名验证失败（577）和应用控制策略（1260），始终保留错误码。
只有 577 且智能应用控制处于 `on` 时才补充“此设备已启用”的上下文；该状态仍不作为具体拦截来源的证明。
`evaluation` 不执行拦截，不据此归因。保护历史、CodeIntegrity / AppLocker 日志是确认用户设备原因的依据。

Linux 上的 Flutter 测试和构建缓存测试不能替代 Windows 设备验证。发版前应核对安装包、卸载程序、主程序、Core、Helper 的签名，
并在 Windows 上分别检查正常启动、受策略阻止时的错误信息、安装升级与卸载。

## 原生验证

`windows-validation.yaml` 在本仓库的相关 PR 和手动请求上运行 Windows 验证，权限只有 `contents: read`。
它执行 Windows 上的 setup_hooks、Rust IPC 与 Helper 测试，并使用仓库签名 Secrets 调用 `test-signing.ps1`：

- 使用临时目录中的小型测试程序代替 Flutter 二进制生成，运行真实 `package.ps1`、`sign.ps1` 和 Inno Setup。
- 检查主程序、Core、Helper、DLL、安装器和卸载器签名、时间戳、篡改拒绝、第三方签名保留、ZIP 和 SHA-256 清单。
- 静默安装测试程序，执行已安装的签名程序，再卸载；临时私钥、证书信任和测试文件在验证后清理。

该工作流不会构建或发布正式应用，也不会创建 Release；来自 fork 的 PR 不使用仓库签名 Secrets。
它验证签名与打包流程，不等同于目标 Windows 设备上的 Smart App Control、Defender 或真实代理运行验证。

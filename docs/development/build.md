# 构建

Go 内核与 Rust Helper 通过 Dart build hook 构建，`setup.dart` 负责打包。Windows 使用本分支的
PowerShell / Inno Setup 签名流程，其余平台使用 distributor，细节见 [.agents/commands.md](../../.agents/commands.md)
与 [Windows 自签名](windows-signing.md)。

| 目标 | 构建位置 | 原因 |
|---|---|---|
| Android APK | GitHub Actions `ubuntu-latest` | 与桌面端同一个发版工作流，签名文件已入库，无需额外密钥 |
| Windows 安装包 / zip | GitHub Actions `windows-2022` | Flutter 不支持在 Linux 上交叉编译 Windows 桌面端 |
| macOS dmg | GitHub Actions `macos-latest`（arm64）与 `macos-15-intel`（x64） | 同上，需要 Xcode |
| format / analyze / test / 代码生成 | 构建 VPS | Windows 本机 `flutter pub get` 需要开发者模式（符号链接） |

工具链版本与上游 CI 保持一致：Flutter 3.47.1、Go 1.26.4、NDK r28c（28.2.13676358）、JDK 17、Rust 1.95.0（由
`plugins/rust_api/rust/rust-toolchain.toml` 固定）。

## 构建 VPS（只做校验）

当前使用机器管理仓库中的 `hostdzire-nl`，已有工具链位于 `/opt/toolchains/flutter`、`/opt/toolchains/go` 和 `/opt/toolchains/rust-1.95.0`，
工作区位于 `/srv/build/po0-clash`。并行任务使用独立的 `/srv/build/po0-<任务名>` 目录。连接参数和机器使用约定以
私有机器管理仓库为准；不要继续使用缺少当前端口的旧 `flclash-vps` 别名。

`scripts/vps/verify.sh` 优先使用这套现有 Flutter / Go 工具链，同时兼容下列旧版初始化脚本的目录。
原生 Rust 校验先将 `/opt/toolchains/rust-1.95.0/bin` 加入 `PATH`。Go 文件权限测试以非 root 用户执行，
避免 root 绕过目录权限导致断言失真；为测试用户指定独立的 `GOCACHE`、`GOMODCACHE` 和 `GOTMPDIR`。

一次性初始化（root）：

```bash
bash scripts/vps/provision.sh
```

脚本把工具链装到 `/opt/flclash-toolchain`，并写入 `/etc/profile.d/flclash-toolchain.sh`。
仓库是公开的，VPS 直接用 HTTPS（`https://github.com/yuuuki-creation/po0-clash.git`）克隆到 `/root/FlClash-po0`，不需要 deploy key；
子模块 `core/Clash.Meta` 通过 `url.https://github.com/.insteadOf git@github.com:` 走 HTTPS。

```bash
bash scripts/vps/verify.sh            # format 检查 + analyze + test + 覆盖率门槛
```

`verify.sh` 会临时把 `pubspec.yaml` 中的 `build_assets` 置为 `false`（跳过 Go / Rust 原生构建）并在退出时恢复。
**永远不要提交 `build_assets: false`**，`setup.dart` 会拒绝在该状态下打包。

构建机只有 11 GB 内存，`provision.sh` 会创建 8 GB swap。VPS 不再构建发版 APK；需要本地试打包时可以在 VPS 上运行
`dart setup.dart android --env stable`，但产物只用于测试，正式产物一律来自 GitHub Actions。

## Windows 原生验证

`windows-validation.yaml` 为本仓库相关 PR 和手动请求执行 Windows 上的 build hooks、Rust IPC / Helper 与签名安装流程验证。
签名安装测试使用临时测试程序，不构建或发布正式应用；详见 [Windows 自签名](windows-signing.md#原生验证)。

## GitHub Actions（发版构建）

`.github/workflows/release.yaml`：

- 触发：只在推送 `v[0-9]*` 标签，或在 Actions 页面手动运行（`workflow_dispatch`，可选填要发布到的标签）时运行。
  **不在分支推送或 PR 上运行**；在维护者明确要求发版之前，不要推送版本标签或手动触发它。
- 任务：Android（三个 ABI 的 APK）、Windows x64（`exe,zip`）、macOS arm64 与 x64（`dmg`），全部使用
  `dart setup.dart <platform> --env stable`；标签构建会先运行 `scripts/check-release-tag.sh`。
- Android 任务按上游 `build.yaml` 的 Android 部分配置（JDK 17、NDK r28c、Gradle、Go、Flutter、Rust 缓存），
  但没有解码密钥 / `google-services.json` 的步骤：签名文件已入库，应用也不再集成 Firebase。
- 全部平台成功后，产物与 `scripts/install-macos.sh` 上传到同名 GitHub Release（流程见 [release.md](release.md)）。

上游的 `.github/workflows/build.yaml` 保持仅手动触发，不用于本分支发版。

## Android 签名

- 发版签名文件**有意提交在仓库中**：`android/app/keystore.jks` 与 `android/signing.properties`
  （`storePassword` / `keyAlias` / `keyPassword`），由 `android/app/build.gradle.kts` 直接读取，CI 不需要任何 secret。
  这是仓库所有者接受其公开的决定，见 [ADR 0006](../adr/0006-standalone-app-identity.md)。
- 两个文件缺一不可，否则 release 构建退回 debug 签名并加上 `.dev` 应用 ID 后缀，产物成了另一个应用，
  不能覆盖升级已安装的 po0-clash。
- 不要替换或重新生成 keystore：签名一变，所有用户都必须卸载重装。除这两个文件外，其他密钥、token、
  `android/local.properties` 仍然不得入库。
- 应用 ID 为 `io.github.yuuukicreation.po0clash`，与官方 FlClash（`com.follow.clash`）不同，两者可以同时安装。

## 本地开发（Windows）

本机可直接编辑代码；需要运行 Flutter 工具时，把改动同步到 VPS 执行：

```bash
git push origin HEAD                          # 或用 tar 同步未提交的改动
ssh hostdzire-nl 'cd /srv/build/po0-clash && git fetch && git checkout <branch> && bash scripts/vps/verify.sh'
```

若本机开启了 Windows 开发者模式，也可以直接在本机运行 `flutter pub get` / `flutter test`（同样先关闭 `build_assets`）。

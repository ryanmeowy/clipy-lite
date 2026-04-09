# Clipy Lite

一个轻量的 macOS 剪贴板历史工具（菜单栏应用），支持文本、文件和图片历史记录，适合日常高频复制粘贴场景。

## 功能特性

- 菜单栏常驻，随时打开剪贴板历史
- 全局快捷键唤起面板（默认：`Cmd + Shift + V`）
- 支持记录以下内容：
  - 文本
  - 文件/文件夹
  - 图片
- 搜索历史记录（按文本或文件名）
- 常用条目可置顶（Pin）
- 支持“纯文本粘贴”
- 快速复制后可自动粘贴（可在设置里开关）
- 支持开机启动

## 系统要求

- macOS 13.0 及以上
- Apple Silicon（当前打包脚本产物为 `arm64`）

## 打包发布（维护者）

项目已内置打包脚本：

```bash
cd /Users/ryan/code/clipy-lite
bash scripts/package_app.sh
```

产物位置：

- App Bundle：`dist/ClipyLite.app`
- 可分发压缩包：`dist/ClipyLite-arm64.zip`

发布到 GitHub：

1. 进入仓库 `Releases` -> `Draft a new release`
2. 填写版本号（如 `v1.0.0`）
3. 上传 `dist/ClipyLite-arm64.zip`
4. 发布

## 目录结构

```text
Sources/               # 应用源码
scripts/package_app.sh # 打包脚本
dist/                  # 打包产物与图标资源
```

## 已知说明

- 当前签名为 ad-hoc（开发分发可用）
- 若用于更广泛分发，建议后续接入 Apple Developer 签名与 Notarization

## License

MIT
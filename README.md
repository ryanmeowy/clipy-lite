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
- Apple Silicon

## 打包发布（维护者）

项目已内置打包脚本：

```bash
cd /Users/ryan/code/clipy-lite
bash scripts/package_app.sh
```

## License

MIT
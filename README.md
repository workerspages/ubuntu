
# 云端 Ubuntu 桌面环境 - S3/WebDAV 数据持久化版 (PaaS 部署专用)

这是一个基于 `lscr.io/linuxserver/webtop:ubuntu-xfce` 构建的云端纯正 Ubuntu 桌面工作站。本项目针对现代无状态 PaaS 平台（如 Zeabur、Railway、Render、Koyeb 等）进行了深度优化，支持将系统配置和桌面数据**加密**后自动同步到 **S3 存储桶** 或 **WebDAV 网盘**，彻底解决云端容器重启导致数据丢失的问题。只需一个浏览器，即可随时随地访问拥有完整图形界面的 Linux 桌面。默认开启了双架构（`linux/amd64`, `linux/arm64`）支持。

## 🌟 核心特性

* **开箱即用的 Web 桌面**: 采用先进的 KasmVNC 技术，无需安装任何客户端，通过浏览器即可获得极其流畅的桌面操作体验，支持剪贴板双向同步。
* **完美的纯中文环境**: 系统底层已深度集成简体中文语言包 (`language-pack-zh-hans`)、文泉驿/Noto 等开源中文字体，并将浏览器的界面彻底中文化，告别乱码。
* **PaaS 平台防冲突机制**: 独创的环境变量代理启动方式。通过自定义 `CUSTOM_PASSWORD` 变量传递密码，完美避开各大 PaaS 平台自动注入 `PASSWORD` 变量导致的登录覆盖和失效问题。
* **数据持久化与加密**: 内置 `rclone` 与自动化生命周期脚本，支持 S3/WebDAV 云盘接入。可选 AES-256 高强度加密，实现文件名及文件内容的完全加密后再离开本地。
* **基础工具链**: 预置了 `curl`, `wget`, `vim`, `git`, `unzip`, `tar`, `socat` 等常用命令行工具，方便随时打开终端进行调试。

## 💡 工作原理

```text
容器启动 → 从 S3/WebDAV 恢复数据 → 启动 ubuntu 桌面服务 → 后台每 N 分钟自动备份数据到远端
```

1. **启动时恢复**: 容器启动阶段，自动使用 `rclone copy` 优先从远端拉取历史备份（如浏览器书签、系统配置）到本地 `/config` 目录。
2. **定时备份**: 通过后台常驻脚本循环 `rclone sync`，单向将本地变化的数据静默同步到远端网盘。
3. **数据加密**: 可选 AES-256 高强度加密，实现文件名及文件内容的完全加密后再离开本地，保护第三方云盘上的隐私安全。

## ⚙️ 环境变量设置

在部署时，请在 PaaS 平台的“环境变量 (Variables)”中配置以下参数：

### 基础设置 (必填)

| 变量名 | 必填 | 说明 | 默认值 |
|--------|------|------|--------|
| `CUSTOM_USER` | ✅ | 自定义登录用户名 | `admin` |
| `CUSTOM_PASSWORD` | ✅ | 自定义登录密码 | `admin` |
| `STORAGE_TYPE` | ✅ | 存储类型: `s3` 或 `webdav` | - |
| `SYNC_INTERVAL` | ❌ | 同步间隔时长（分钟） | `5` |

### S3 配置（`STORAGE_TYPE=s3`）

| 变量名 | 必填 | 说明 | 默认值 |
|--------|------|------|--------|
| `S3_ENDPOINT` | ✅ | S3 端点 URL | - |
| `S3_ACCESS_KEY` | ✅ | Access Key | - |
| `S3_SECRET_KEY` | ✅ | Secret Key | - |
| `S3_BUCKET` | ✅ | 存储桶名称 | - |
| `S3_REGION` | ❌ | 区域 | `us-east-1` |
| `S3_PATH` | ❌ | 桶内子路径 | `ubuntu` |

### WebDAV 配置（`STORAGE_TYPE=webdav`）

| 变量名 | 必填 | 说明 | 默认值 |
|--------|------|------|--------|
| `WEBDAV_URL` | ✅ | WebDAV 服务器 URL | - |
| `WEBDAV_USER` | ✅ | 用户名 | - |
| `WEBDAV_PASS` | ✅ | 密码 | - |
| `WEBDAV_VENDOR` | ❌ | 供应商类型 (`nextcloud`/`owncloud`/`other`) | `other` |
| `WEBDAV_PATH` | ❌ | 远端子路径 | `ubuntu` |

### 🔒 加密配置（高度推荐使用）

设置 `ENCRYPT_PASSWORD` 即可启用 AES-256 加密。您的加密密码不仅保护文件内容，也保护文件名。下载恢复时脚本会自动进行解密。

| 变量名 | 必填 | 说明 | 默认值 |
|--------|------|------|--------|
| `ENCRYPT_PASSWORD` | ❌ | 加密密码（设置后则启用加密） | - |
| `ENCRYPT_SALT` | ❌ | 加密盐值（进一步增强安全性） | - |

> ⚠️ **重要安全提示**：
> - ⚠️ 加密密码一旦设置后**不可更改或丢失**，否则已加密的备份数据将**绝对无法解密**。
> - 💡 建议同时设置 `ENCRYPT_PASSWORD` 和 `ENCRYPT_SALT` 获取最高安全性。
> - 🛑 首次启用加密时，远端目标**必须**为空目录；不能对已有的未加密备份直接应用加密，请先清理或更换备份路径。

## 🚀 部署指南 (针对无状态 PaaS)

在类似 Railway、Render、Fly.io、Koyeb 等 PaaS 平台部署时极其简单：

1. **镜像拉取**: 指定镜像为 `ghcr.io/workerspages/ubuntu-oss:latest` 或 `docker.io/workerspages/ubuntu-oss:latest`。
2. **端口设置**: 容器默认通过 Cloudflare 兼容的 HTTP 端口暴露服务：**`8080`**。
3. **注入变量**: 填补上述的环境变量表，配置好您的 `CUSTOM_PASSWORD` 密码，并依据您使用的存储方案分配 S3 或是 WebDAV 的密钥信息。
4. **启动服务**: 容器将会在拉取云端历史配置数据后，在 `8080` 端口开启 ubuntu 面板服务。

> **性能提示**: 建议将 `SYNC_INTERVAL` 维持在建议的 5-10 分钟左右，以避免过于频繁的网络 I/O 带来的微小性能影响。

## 📂 项目结构

```text
.
├── .github/
│   └── workflows/
│       └── docker-build.yml  # GitHub Actions 自动化构建和推送配置
├── Dockerfile                # 核心镜像构建指令及 S3/WebDAV 自动同步逻辑
└── README.md                 # 项目说明文档 (本文档)
```

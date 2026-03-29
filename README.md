
# 云端 Ubuntu 桌面环境 (PaaS 部署专用)

这是一个基于 `lscr.io/linuxserver/webtop:ubuntu-xfce` 构建的云端纯正 Ubuntu 桌面工作站。本项目针对现代 PaaS 平台（如 Zeabur、Railway 等）进行了深度优化，解决了环境变量冲突与语言本地化问题，让您只需一个浏览器，即可随时随地访问拥有完整图形界面的 Linux 桌面。

## 🌟 核心特性

* **开箱即用的 Web 桌面**: 采用先进的 KasmVNC 技术，无需安装任何客户端，通过浏览器即可获得极其流畅的桌面操作体验，支持剪贴板双向同步。
* **完美的纯中文环境**: 系统底层已深度集成简体中文语言包 (`language-pack-zh-hans`)、文泉驿/Noto 等开源中文字体，并将 Chromium 浏览器的界面彻底中文化，告别乱码和英文界面。
* **PaaS 平台防冲突机制**: 独创的环境变量代理启动方式。通过自定义 `WEBTOP_PASSWORD` 变量传递密码，完美避开各大 PaaS 平台自动注入 `PASSWORD` 变量导致的登录覆盖和失效问题。
* **海量数据同步利器**: 预装了强大的 `rclone` 工具，非常适合在云端直接挂载各大网盘。无论是处理高达几百GB的大型备份任务，还是管理类似 iPhone 备份、WeChat_BackupFiles 微信记录、以及庞大的影视资源库，都能在云端高速且稳定地完成流转。
* **基础工具链**: 预置了 `curl`, `wget`, `vim`, `git`, `unzip`, `tar` 等常用命令行工具，方便随时打开终端进行调试。

## 📂 项目结构

```text
.
├── .github/
│   └── workflows/
│       └── docker-build.yml  # GitHub Actions 自动化构建和推送配置
├── Dockerfile                # 核心镜像构建指令及环境变量配置
└── README.md                 # 项目说明文档 (本文档)
```

## 🚀 部署与使用指南

### 1. 环境变量配置

在部署到云平台（如 Zeabur）时，请务必在服务的“环境变量 (Variables)”设置中添加以下参数，以确保系统的安全与正常访问：

* `CUSTOM_USER`: 设置您的自定义登录用户名（如 `admin`）
* `WEBTOP_PASSWORD`: 设置您的专属高强度登录密码（如 `admin`）

### 2. 网络端口设置

本镜像底层的 Webtop 默认通过 **`3000`** 端口提供 Web 服务。请确保在 PaaS 平台的网络配置中，将对外暴露的域名路由指向容器内部的 `3000` 端口。

### 3. 本地快速测试

如果您已在本地安装了 Docker，可以通过以下命令直接拉取构建并运行测试：

```bash
# 构建镜像
docker build -t my-cloud-desktop .

# 运行容器 (请将用户名和密码替换为您自己的)
docker run -d \
  --name ubuntu-desktop \
  -p 3000:3000 \
  -e CUSTOM_USER="admin" \
  -e WEBTOP_PASSWORD="admin" \
  my-cloud-desktop
```
运行后，在浏览器访问 `http://localhost:3000` 即可进入桌面。

## 🛠️ 云端容器的“无状态”特性与软件安装

本系统是一个标准且完整的 Ubuntu 环境。您可以在桌面的终端中使用 `sudo apt update` 和 `sudo apt install` 随意安装任何 Linux 软件（如代码编辑器、网络工具等）。

**⚠️ 重要提示：**
PaaS 平台上的 Docker 容器是**无状态（Ephemeral）**的。当容器重启或平台重新部署时，您通过终端手动安装的软件将会丢失，系统会恢复到 `Dockerfile` 定义的初始状态。

**最佳实践**：如果您需要某款软件（例如特定版本的 Node.js 或 Python 环境）永久驻留在系统中，请将该软件的安装命令直接补充到本项目根目录的 `Dockerfile` 的 `RUN apt-get install` 列表中，并推送到 GitHub。自动化流水线会为您构建一个包含该软件的全新永久镜像。

---
*Powered by Docker, LinuxServer Webtop & GitHub Actions*

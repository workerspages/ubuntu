
# Ubuntu Docker 镜像 (PaaS 部署专用)

这是一个基于官方 Ubuntu 22.04 LTS 构建的自定义 Docker 镜像项目。该镜像通过 GitHub Actions 自动构建，并推送到 GitHub 容器注册表 (GHCR)。为了完美适配各种 PaaS（平台即服务，如 Render, Railway, Fly.io 等）的部署需求，容器内置了一个轻量级的 Python HTTP 服务以保持持续运行。

## 🌟 特性

* **基础镜像**: 官方 Ubuntu 22.04 LTS
* **自动构建**: 配置了 GitHub Actions 工作流，当代码推送到 `main` 分支时，会自动触发构建并发布到 GHCR。
* **PaaS 友好**: 默认启动基于 Python 3 的简易 HTTP 服务器 (监听 8080 端口)，防止容器在 PaaS 平台上因缺少常驻后台进程而不断重启。
* **预装工具**: 包含了常用的基础工具集，方便直接在云端控制台进入终端进行调试和开发：
  * `curl`, `wget` (网络请求)
  * `vim` (文本编辑)
  * `git` (代码与版本控制)
  * `unzip`, `tar` (文件压缩与解压)
  * `python3`, `python3-pip` (Python 运行环境及包管理)
* **环境优化**: 默认配置为 `Asia/Shanghai` 时区，并设置了非交互式构建 (`DEBIAN_FRONTEND=noninteractive`) 以加速和稳定构建过程。

## 📂 项目结构

```text
.
├── .github/
│   └── workflows/
│       └── docker-build.yml  # GitHub Actions 自动化构建和推送的配置文件
├── Dockerfile                # Docker 镜像构建指令及环境配置
└── README.md                 # 项目说明文档 (本文档)
```

## 🚀 如何使用

### 1. 本地构建与运行测试

如果您想在本地测试此镜像，请确保已安装 Docker，然后在项目根目录下打开终端运行：

```bash
# 构建 Docker 镜像
docker build -t ubuntu-paas-env .

# 运行容器并将容器内的 8080 端口映射到本机的 8080 端口
docker run -p 8080:8080 ubuntu-paas-env
```
随后，打开浏览器访问 `http://localhost:8080`，您将看到 "Hello from Ubuntu Container on PaaS!" 的欢迎信息，证明服务运行正常。

### 2. 从 GHCR 拉取云端镜像

GitHub Actions 会自动将构建好的镜像发布到您 GitHub 账号的 Packages (GHCR) 中。您可以在任何机器上通过以下命令直接拉取（**注意：请将 `YOUR_USERNAME/YOUR_REPO` 替换为您实际的 GitHub 用户名和仓库名**）：

```bash
docker pull ghcr.io/YOUR_USERNAME/YOUR_REPO:latest
```

### 3. 在 PaaS 平台部署

绝大多数现代云端 PaaS 平台（如 Railway, Render, Koyeb, Fly.io 等）都完美支持此项目。您可以选择以下两种主流方式之一进行部署：

* **源码关联部署 (推荐)**: 在 PaaS 平台后台新建服务，授权访问您的 GitHub 仓库。平台会自动读取仓库根目录的 `Dockerfile` 进行云端构建和自动部署。
* **镜像直接部署**: 在 PaaS 平台上选择 "从 Docker Registry 部署"，输入您的 GHCR 镜像地址（如 `ghcr.io/YOUR_USERNAME/YOUR_REPO:latest`）即可。
* **端口配置提示**: 无论使用哪种方式，请确保在 PaaS 的服务网络设置中，将外部访问端口指向容器内部暴露的 `8080` 端口。

## 🛠️ 如何定制化修改

您可以完全根据自己的实际业务需求修改根目录下的 `Dockerfile`：
* **安装其他软件**: 在 `RUN apt-get install` 命令行后面追加您需要的 Ubuntu 软件包名称（例如 `nodejs`, `npm`, `openjdk-17-jdk` 等）。
* **修改默认运行服务**: 如果您想运行自己的 Node.js 应用、Java Spring Boot 或其他 Web 框架，请替换掉 `Dockerfile` 末尾的 `CMD ["python3", "-m", "http.server", "8080"]` 指令，并根据应用实际情况修改 `EXPOSE` 暴露的端口号。

---
*此项目由 GitHub Actions 驱动 CI/CD 自动化构建*


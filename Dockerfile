# 使用官方 Ubuntu 22.04 LTS 作为基础镜像
FROM ubuntu:22.04

# 设置维护者信息（可选）
LABEL maintainer="your-email@example.com"

# 设置环境变量，防止在 apt-get 安装过程中出现交互式对话框卡住构建
ENV DEBIAN_FRONTEND=noninteractive

# 设置时区环境变量（以亚洲/上海为例）
ENV TZ=Asia/Shanghai

# 更新软件源，安装常用基础工具以及 Python3（用于启动常驻 Web 服务）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        vim \
        git \
        ca-certificates \
        tzdata \
        unzip \
        tar \
        python3 \
        python3-pip && \
    # 配置时区
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # 清理 APT 缓存，减少最终镜像的大小
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 创建并设置工作目录
WORKDIR /workspace

# 创建一个简单的欢迎页面，用于验证部署是否成功
RUN echo "<h1>Hello from Ubuntu Container on PaaS!</h1>" > index.html

# 暴露 8080 端口（PaaS 平台会将公网流量路由到这个端口）
EXPOSE 8080

# 容器启动时的默认命令：启动 Python 自带的简易 HTTP 服务器
# 这将使容器保持运行状态，监听 8080 端口
CMD ["python3", "-m", "http.server", "8080"]

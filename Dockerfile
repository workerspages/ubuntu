# 使用官方 Ubuntu 22.04 LTS 作为基础镜像
FROM ubuntu:22.04

# 设置维护者信息（可选）
LABEL maintainer="your-email@example.com"

# 设置环境变量，防止在 apt-get 安装过程中出现交互式对话框卡住构建
ENV DEBIAN_FRONTEND=noninteractive

# 设置时区环境变量（以亚洲/上海为例）
ENV TZ=Asia/Shanghai

# 更新软件源，安装常用基础工具，并清理缓存以缩减镜像体积
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        vim \
        git \
        ca-certificates \
        tzdata \
        unzip \
        tar && \
    # 配置时区
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # 清理 APT 缓存，减少最终镜像的大小
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 创建并设置工作目录
WORKDIR /workspace

# 容器启动时的默认命令，这里设置为启动 bash 终端
CMD ["/bin/bash"]

# 使用 LinuxServer 团队维护的 Ubuntu XFCE 桌面镜像作为基础
FROM lscr.io/linuxserver/webtop:ubuntu-xfce

# 设置环境变量 (可选)
# PUID 和 PGID 用于解决容器内外文件权限问题
ENV PUID=1000
ENV PGID=1000
# 设置时区
ENV TZ=Asia/Shanghai
# 禁用基本的 HTTP 认证（如果部署在公网，建议设为 true 并通过环境变量设置密码）
ENV DOCKER_MODS=linuxserver/mods:webtop-vnc-password-auth

# 更新软件源并安装您个人需要的工具（例如用来同步备份几百GB数据的 rclone，以及基础工具）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        vim \
        git \
        unzip \
        tar \
        rclone && \
    # 清理 APT 缓存，减少最终镜像的大小
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /workspace

# Webtop 默认通过 3000 端口提供流畅的网页版桌面访问
EXPOSE 3000

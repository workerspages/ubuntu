# 使用官方 Ubuntu 22.04 LTS 作为基础镜像
FROM ubuntu:22.04

# 设置维护者信息（可选）
LABEL maintainer="your-email@example.com"

# 设置环境变量，防止交互式对话框，并配置时区
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
ENV USER=root

# 安装轻量级桌面环境 (XFCE4)、VNC 服务及相关组件、noVNC (Web代理)、以及常用工具
# 注意：添加了 tigervnc-tools 以提供 vncpasswd 命令
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        xfce4 \
        xfce4-terminal \
        tigervnc-standalone-server \
        tigervnc-tools \
        novnc \
        websockify \
        curl \
        wget \
        vim \
        git \
        unzip \
        tar \
        rclone \
        dbus-x11 \
        x11-xserver-utils && \
    # 配置时区
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # 清理 APT 缓存，减少最终镜像的大小
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 配置 noVNC 的默认网页访问入口
RUN ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# 设置 VNC 的访问密码（这里默认设置为 "password"，您可以自行修改）
RUN mkdir -p ~/.vnc && \
    echo "password" | vncpasswd -f > ~/.vnc/passwd && \
    chmod 600 ~/.vnc/passwd

# 配置 VNC 启动脚本，确保连接时正确加载 XFCE4 桌面环境
RUN echo "#!/bin/sh\nstartxfce4" > ~/.vnc/xstartup && \
    chmod +x ~/.vnc/xstartup

# 创建并设置工作目录
WORKDIR /workspace

# 暴露 8080 端口供浏览器访问
EXPOSE 8080

# 容器启动命令：使用 Docker 推荐的 JSON 数组格式
# 1. 启动 VNC 服务器，设置分辨率为 1280x720 (运行在 :1 也就是 5901 端口)
# 2. 启动 websockify (noVNC)，将 5901 的 VNC 画面代理到 8080 端口供网页访问
CMD ["/bin/sh", "-c", "vncserver :1 -geometry 1280x720 -depth 24 && websockify --web=/usr/share/novnc/ 8080 localhost:5901"]

# 使用 LinuxServer 团队维护的 Ubuntu XFCE 桌面镜像作为基础
FROM lscr.io/linuxserver/webtop:ubuntu-xfce

# 设置环境变量，配置中文本地化、时区及权限参数
ENV PUID=1000
ENV PGID=1000
ENV TZ=Asia/Shanghai
ENV LANG=zh_CN.UTF-8
ENV LANGUAGE=zh_CN:zh
ENV LC_ALL=zh_CN.UTF-8

ENV CUSTOM_USER="admin"
ENV CUSTOM_PASSWORD="admin"

# 更新软件源并安装中文语言包、中文字体以及您的常用工具
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        language-pack-zh-hans \
        fonts-wqy-zenhei \
        fonts-wqy-microhei \
        fonts-noto-cjk \
        curl \
        wget \
        vim \
        git \
        unzip \
        tar \
        rclone && \
    # 生成并应用中文 locale
    locale-gen zh_CN.UTF-8 && \
    update-locale LANG=zh_CN.UTF-8 && \
    # 清理 APT 缓存，减少最终镜像的大小
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /workspace

# Webtop 默认通过 3000 端口提供流畅的网页版桌面访问
EXPOSE 3000

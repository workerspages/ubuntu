# 使用 LinuxServer 团队维护的 Ubuntu XFCE 桌面镜像作为基础
FROM lscr.io/linuxserver/webtop:ubuntu-xfce

# 设置环境变量，配置中文本地化、时区及权限参数
ENV PUID=1000
ENV PGID=1000
ENV TZ=Asia/Shanghai
ENV LANG=zh_CN.UTF-8
ENV LANGUAGE=zh_CN:zh
ENV LC_ALL=zh_CN.UTF-8

# 设置自定义的登录账号
ENV CUSTOM_USER="admin"

# 使用自定义变量名来设置密码，完美避开 PaaS 平台的 PASSWORD 变量冲突
ENV CUSTOM_PASSWORD="你的复杂密码"

# 更新软件源并安装中文语言包、中文字体以及您的常用工具（包含 cron 用于后台定时同步）
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
        rclone \
        cron && \
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

# 生成启动与自动同步脚本 (方案 B: Rclone 结合启动/退出脚本同步 /config 目录)
RUN { \
    echo '#!/bin/bash'; \
    echo 'export PASSWORD=$CUSTOM_PASSWORD'; \
    echo ''; \
    echo '# 1. 动态生成 Rclone 配置文件'; \
    echo 'if [ -n "$RCLONE_CONF_BASE64" ]; then'; \
    echo '    mkdir -p /root/.config/rclone'; \
    echo '    echo "$RCLONE_CONF_BASE64" | base64 -d > /root/.config/rclone/rclone.conf'; \
    echo 'fi'; \
    echo ''; \
    echo '# 2. 启动时拉取历史配置数据，并配置定时回写'; \
    echo 'if [ -n "$RCLONE_REMOTE_PATH" ]; then'; \
    echo '    echo "正在从 $RCLONE_REMOTE_PATH 拉取浏览器及系统配置到 /config..."'; \
    echo '    rclone copy "$RCLONE_REMOTE_PATH" /config --ignore-errors'; \
    echo '    '; \
    echo '    # 设置定时任务：每 15 分钟在后台将 /config 的变动静默同步回网盘'; \
    echo '    echo "*/15 * * * * root rclone sync /config \"$RCLONE_REMOTE_PATH\" --ignore-errors > /dev/null 2>&1" > /etc/cron.d/rclone-sync'; \
    echo '    chmod 0644 /etc/cron.d/rclone-sync'; \
    echo '    crontab /etc/cron.d/rclone-sync'; \
    echo '    service cron start'; \
    echo 'fi'; \
    echo ''; \
    echo '# 3. 接管并启动桌面环境主程序'; \
    echo 'exec /init'; \
} > /start.sh && chmod +x /start.sh

# 使用自定义的启动脚本覆盖默认启动入口
ENTRYPOINT ["/start.sh"]

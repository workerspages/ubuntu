# 使用 accetto 的 Ubuntu XFCE Firefox G3 镜像作为基础
FROM accetto/ubuntu-vnc-xfce-firefox-g3:latest

# 切换到 root 用户以安装必要的系统环境和工具
USER 0

# 安装中文语言包、中文字体以及 rclone
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        language-pack-zh-hans \
        fonts-wqy-zenhei \
        fonts-wqy-microhei \
        fonts-noto-cjk \
        rclone && \
    # 生成并应用中文 locale
    locale-gen zh_CN.UTF-8 && \
    update-locale LANG=zh_CN.UTF-8 && \
    # 清理 APT 缓存，减少最终镜像的体积
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 针对部分 PaaS 平台强制以随机无权限 UID 运行容器的严格安全策略
# 提前赋予主目录最高读写权限，并移交所有权 (UID 1001)，彻底防止 rclone 写入或修改时间戳失败
RUN chmod 777 /tmp && \
    mkdir -p /home/headless/.config && \
    chown -R 1001:0 /home/headless && \
    chmod -R 777 /home/headless

# 设置环境变量，配置中文本地化及桌面参数
ENV TZ=Asia/Shanghai
ENV LANG=zh_CN.UTF-8
ENV LANGUAGE=zh_CN:zh
ENV LC_ALL=zh_CN.UTF-8

# accetto 镜像默认使用 VNC_PW 控制桌面密码
ENV VNC_PW="你的复杂密码"
# 兼容您之前在 PaaS 平台上设定的自定义密码变量名
ENV CUSTOM_PASSWORD="你的复杂密码"

# 核心魔法：生成启动与 S3/WebDAV 自动同步脚本
RUN { \
    echo '#!/bin/bash'; \
    echo ''; \
    echo 'echo "=== 初始化 S3/WebDAV 数据持久化流程 ==="'; \
    echo ''; \
    echo '# accetto 镜像的用户数据统一位于 /home/headless'; \
    echo 'HOME_DIR="/home/headless"'; \
    echo ''; \
    echo '# 1. 动态生成 Rclone 配置文件 (放置在 /tmp 目录，彻底规避 PaaS 权限限制)'; \
    echo 'CONF_FILE="/tmp/rclone.conf"'; \
    echo 'rm -f "$CONF_FILE"'; \
    echo 'touch "$CONF_FILE"'; \
    echo 'chmod 666 "$CONF_FILE" 2>/dev/null || true'; \
    echo ''; \
    echo 'BASE_REMOTE=""'; \
    echo ''; \
    echo 'if [ "$STORAGE_TYPE" = "s3" ]; then'; \
    echo '    echo "配置 S3 存储端点..."'; \
    echo '    echo "[backend]" >> "$CONF_FILE"'; \
    echo '    echo "type = s3" >> "$CONF_FILE"'; \
    echo '    echo "provider = Other" >> "$CONF_FILE"'; \
    echo '    echo "endpoint = $S3_ENDPOINT" >> "$CONF_FILE"'; \
    echo '    echo "access_key_id = $S3_ACCESS_KEY" >> "$CONF_FILE"'; \
    echo '    echo "secret_access_key = $S3_SECRET_KEY" >> "$CONF_FILE"'; \
    echo '    echo "region = ${S3_REGION:-us-east-1}" >> "$CONF_FILE"'; \
    echo '    BASE_REMOTE="backend:${S3_BUCKET}/${S3_PATH:-ubuntu}"'; \
    echo 'elif [ "$STORAGE_TYPE" = "webdav" ]; then'; \
    echo '    echo "配置 WebDAV 存储端点..."'; \
    echo '    echo "[backend]" >> "$CONF_FILE"'; \
    echo '    echo "type = webdav" >> "$CONF_FILE"'; \
    echo '    echo "url = $WEBDAV_URL" >> "$CONF_FILE"'; \
    echo '    echo "vendor = ${WEBDAV_VENDOR:-other}" >> "$CONF_FILE"'; \
    echo '    echo "user = $WEBDAV_USER" >> "$CONF_FILE"'; \
    echo '    OBSCURED_PASS=$(rclone obscure "$WEBDAV_PASS")'; \
    echo '    echo "pass = $OBSCURED_PASS" >> "$CONF_FILE"'; \
    echo '    BASE_REMOTE="backend:${WEBDAV_PATH:-ubuntu}"'; \
    echo 'fi'; \
    echo ''; \
    echo 'TARGET_REMOTE="$BASE_REMOTE"'; \
    echo ''; \
    echo '# 2. 配置 AES-256 加密层 (可选)'; \
    echo 'if [ -n "$TARGET_REMOTE" ] && [ -n "$ENCRYPT_PASSWORD" ]; then'; \
    echo '    echo "检测到加密密码，正在配置 AES-256 加密层..."'; \
    echo '    echo "[secure]" >> "$CONF_FILE"'; \
    echo '    echo "type = crypt" >> "$CONF_FILE"'; \
    echo '    echo "remote = $BASE_REMOTE" >> "$CONF_FILE"'; \
    echo '    OBSCURED_ENC_PASS=$(rclone obscure "$ENCRYPT_PASSWORD")'; \
    echo '    echo "password = $OBSCURED_ENC_PASS" >> "$CONF_FILE"'; \
    echo '    if [ -n "$ENCRYPT_SALT" ]; then'; \
    echo '        OBSCURED_SALT=$(rclone obscure "$ENCRYPT_SALT")'; \
    echo '        echo "salt = $OBSCURED_SALT" >> "$CONF_FILE"'; \
    echo '    fi'; \
    echo '    TARGET_REMOTE="secure:"'; \
    echo 'fi'; \
    echo ''; \
    echo '# 定义 Rclone 核心参数 (加入 -L 处理软链接，并排除系统核心缓存防止破坏桌面环境)'; \
    echo 'RCLONE_OPTS="-L --exclude=/.vnc/** --exclude=/.cache/** --exclude=/.dbus/** --exclude=/log/** --exclude=/.X*-lock --exclude=/.X11-unix/** --exclude=/.ICEauthority --exclude=/.Xauthority --exclude=/.local/state/**"'; \
    echo ''; \
    echo '# 3. 容器启动时恢复历史数据'; \
    echo 'if [ -n "$TARGET_REMOTE" ]; then'; \
    echo '    echo "初始化检测远端目录是否存在 (避免首次运行报错)..."'; \
    echo '    rclone mkdir "$TARGET_REMOTE" --config="$CONF_FILE" 2>/dev/null'; \
    echo '    '; \
    echo '    echo "[$(date "+%Y-%m-%d %H:%M:%S")] 正在从 $TARGET_REMOTE 恢复核心配置数据到 $HOME_DIR..."'; \
    echo '    rclone copy "$TARGET_REMOTE" $HOME_DIR --config="$CONF_FILE" $RCLONE_OPTS --ignore-errors'; \
    echo '    echo "[$(date "+%Y-%m-%d %H:%M:%S")] 恢复数据完毕。"'; \
    echo '    '; \
    echo '    # 4. 启动后台守护进程，执行自动同步'; \
    echo '    INTERVAL=${SYNC_INTERVAL:-5}'; \
    echo '    ('; \
    echo '        while true; do'; \
    echo '            sleep $((INTERVAL * 60))'; \
    echo '            echo "[$(date "+%Y-%m-%d %H:%M:%S")] 开始后台自动同步 $HOME_DIR 到 $TARGET_REMOTE..."'; \
    echo '            rclone sync $HOME_DIR "$TARGET_REMOTE" --config="$CONF_FILE" $RCLONE_OPTS --ignore-errors > /dev/null 2>&1'; \
    echo '            echo "[$(date "+%Y-%m-%d %H:%M:%S")] 同步完成。"'; \
    echo '        done'; \
    echo '    ) &'; \
    echo 'else'; \
    echo '    echo "⚠️ 未配置有效的 STORAGE_TYPE (s3/webdav)，跳过数据恢复与自动同步。"'; \
    echo 'fi'; \
    echo ''; \
    echo '# 自动清理可能残留的桌面锁文件，防止 Web 桌面启动死锁'; \
    echo 'rm -rf $HOME_DIR/.vnc/*.pid $HOME_DIR/.X*-lock /tmp/.X11-unix 2>/dev/null'; \
    echo ''; \
    echo '# 自动将您的 CUSTOM_PASSWORD 转换为 accetto 原生的 VNC_PW'; \
    echo 'if [ -n "$CUSTOM_PASSWORD" ] && [ "$CUSTOM_PASSWORD" != "你的复杂密码" ]; then'; \
    echo '    export VNC_PW=$CUSTOM_PASSWORD'; \
    echo 'fi'; \
    echo ''; \
    echo '# 5. 接管并启动 accetto 默认桌面环境主程序'; \
    echo 'echo "拉起 Ubuntu Web 桌面..."'; \
    echo 'exec /dockerstartup/startup.sh "$@"'; \
} > /sync-and-start.sh && chmod +x /sync-and-start.sh

# 切换回 accetto 镜像内定的普通安全用户 (headless)
USER headless

# 设置工作目录
WORKDIR /home/headless

# accetto 默认通过 6901 端口提供 noVNC (网页) 服务
EXPOSE 6901

# 使用 tini 接管进程并执行我们的同步与拉起脚本
ENTRYPOINT ["/usr/bin/tini", "--", "/sync-and-start.sh"]

# 默认参数，指示 accetto 保持 UI 服务常驻
CMD ["--wait"]

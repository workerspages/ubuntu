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
# 使用自定义变量名来设置密码，避开 PaaS 平台的变量冲突
ENV CUSTOM_PASSWORD="你的复杂密码"

# 更新软件源并安装中文语言包、字体以及核心工具 
# (包含 socat 工具，用于实现 8080 端口映射)
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
        socat && \
    # 生成并应用中文 locale
    locale-gen zh_CN.UTF-8 && \
    update-locale LANG=zh_CN.UTF-8 && \
    # 清理 APT 缓存，减少最终镜像的大小
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /workspace

# 对外暴露服务端端口
EXPOSE 8080

# 核心魔法：生成启动与 S3/WebDAV 自动同步脚本
RUN { \
    echo '#!/bin/bash'; \
    echo ''; \
    echo 'echo "=== 初始化 S3/WebDAV 数据持久化流程 ==="'; \
    echo ''; \
    echo '# 1. 动态生成 Rclone 配置文件'; \
    echo 'mkdir -p /root/.config/rclone'; \
    echo 'CONF_FILE="/root/.config/rclone/rclone.conf"'; \
    echo '> "$CONF_FILE"'; \
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
    echo '# 3. 容器启动时恢复历史数据 (已增加 --config 显式指定配置路径)'; \
    echo 'if [ -n "$TARGET_REMOTE" ]; then'; \
    echo '    echo "正在从 $TARGET_REMOTE 恢复数据到 /config..."'; \
    echo '    rclone copy "$TARGET_REMOTE" /config --config="$CONF_FILE" --ignore-errors'; \
    echo '    '; \
    echo '    # 4. 启动后台守护进程，执行自动同步 (已增加 --config 显式指定配置路径)'; \
    echo '    INTERVAL=${SYNC_INTERVAL:-5}'; \
    echo '    ('; \
    echo '        while true; do'; \
    echo '            sleep $((INTERVAL * 60))'; \
    echo '            echo "[$(date)] 开始后台自动同步 /config 到 $TARGET_REMOTE..."'; \
    echo '            rclone sync /config "$TARGET_REMOTE" --config="$CONF_FILE" --ignore-errors'; \
    echo '            echo "[$(date)] 同步完成"'; \
    echo '        done'; \
    echo '    ) &'; \
    echo 'else'; \
    echo '    echo "⚠️ 未配置有效的 STORAGE_TYPE (s3/webdav)，跳过数据恢复与自动同步。"'; \
    echo 'fi'; \
    echo ''; \
    echo '# 将我们的 CUSTOM_PASSWORD 赋值给 webtop 默认识别的 PASSWORD'; \
    echo 'export PASSWORD=$CUSTOM_PASSWORD'; \
    echo ''; \
    echo '# 5. 端口转发 (利用 socat 将基础镜像内定的 3000 端口转发至约定的 8080 端口)'; \
    echo 'echo "启动 8080 端口映射服务..."'; \
    echo 'socat TCP-LISTEN:8080,fork,reuseaddr TCP:127.0.0.1:3000 &'; \
    echo ''; \
    echo '# 6. 接管并启动 webtop 默认环境主程序'; \
    echo 'echo "拉起 Ubuntu Web 桌面..."'; \
    echo 'exec /init'; \
} > /sync-and-start.sh && chmod +x /sync-and-start.sh

# 覆盖默认启动入口，注入完整生命周期管理脚本
ENTRYPOINT ["/sync-and-start.sh"]

FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# =========================================================
# LIGHTWEIGHT XFCE + XRDP
# =========================================================

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-terminal \
    xrdp \
    xorgxrdp \
    dbus \
    dbus-x11 \
    sudo \
    xdg-utils \
    xz-utils \
    ca-certificates \
    curl \
    wget \
    nano \
    procps \
    net-tools \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# =========================================================
# KALI WALLPAPER
# =========================================================

COPY kali-wallpaper.jpg /usr/share/backgrounds/kali-wallpaper.jpg

RUN chmod 644 /usr/share/backgrounds/kali-wallpaper.jpg

# =========================================================
# FIREFOX
# Mozilla Linux 64-bit tar.xz
# =========================================================

RUN mkdir -p /opt/firefox && \
    wget -q \
    "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US" \
    -O /tmp/firefox.tar.xz && \
    tar -xJf /tmp/firefox.tar.xz \
    --strip-components=1 \
    -C /opt/firefox && \
    rm -f /tmp/firefox.tar.xz && \
    ln -sf /opt/firefox/firefox /usr/local/bin/firefox && \
    update-alternatives --install \
    /usr/bin/x-www-browser \
    x-www-browser \
    /usr/local/bin/firefox \
    100

# =========================================================
# FIREFOX DESKTOP ICON
# =========================================================

RUN printf '%s\n' \
'[Desktop Entry]' \
'Name=Firefox' \
'Comment=Web Browser' \
'Exec=/usr/local/bin/firefox %u' \
'Icon=/opt/firefox/browser/chrome/icons/default/default128.png' \
'Terminal=false' \
'Type=Application' \
'Categories=Network;WebBrowser;' \
'MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;' \
> /usr/share/applications/firefox.desktop

# =========================================================
# XRDP STARTWM
# =========================================================

RUN printf '%s\n' \
'#!/bin/sh' \
'unset DBUS_SESSION_BUS_ADDRESS' \
'unset XDG_RUNTIME_DIR' \
'export LANG=C.UTF-8' \
'export LANGUAGE=C.UTF-8' \
'export LC_ALL=C.UTF-8' \
'exec dbus-launch --exit-with-session startxfce4' \
> /etc/xrdp/startwm.sh && \
chmod +x /etc/xrdp/startwm.sh

# =========================================================
# DESKTOP STARTUP SCRIPT
# =========================================================

RUN printf '%s\n' \
'#!/bin/bash' \
'WALLPAPER="/usr/share/backgrounds/kali-wallpaper.jpg"' \
'export BROWSER="/usr/local/bin/firefox"' \
'sleep 3' \
'if command -v xdg-settings >/dev/null 2>&1; then' \
'    xdg-settings set default-web-browser firefox.desktop 2>/dev/null || true' \
'fi' \
'if command -v xfconf-query >/dev/null 2>&1; then' \
'    PROPS="$(xfconf-query -c xfce4-desktop -l 2>/dev/null || true)"' \
'    echo "$PROPS" | grep "/last-image$" | while read -r P; do' \
'        xfconf-query -c xfce4-desktop -p "$P" -s "$WALLPAPER" 2>/dev/null || true' \
'    done' \
'    echo "$PROPS" | grep "/image-style$" | while read -r P; do' \
'        xfconf-query -c xfce4-desktop -p "$P" -s 5 2>/dev/null || true' \
'    done' \
'    xfdesktop --reload 2>/dev/null || true' \
'fi' \
'wait' \
> /usr/local/bin/set-desktop.sh && \
chmod +x /usr/local/bin/set-desktop.sh

# =========================================================
# XRDP USER + START SCRIPT
# =========================================================

RUN printf '%s\n' \
'#!/bin/bash' \
'set -u' \
'RDP_USERNAME="desktop"' \
'RDP_PASSWORD="Desktop2026"' \
'if [ "$RDP_USERNAME" = "root" ] || [ -z "$RDP_USERNAME" ]; then RDP_USERNAME="desktop"; fi' \
'if [ -z "$RDP_PASSWORD" ]; then RDP_PASSWORD="Desktop2026"; fi' \
'echo "========================================"' \
'echo "     LIGHTWEIGHT XFCE + XRDP"' \
'echo "========================================"' \
'echo "Creating user: $RDP_USERNAME"' \
'if ! id "$RDP_USERNAME" >/dev/null 2>&1; then useradd -m -s /bin/bash "$RDP_USERNAME"; fi' \
'echo "$RDP_USERNAME:$RDP_PASSWORD" | chpasswd' \
'usermod -aG sudo "$RDP_USERNAME" 2>/dev/null || true' \
'USER_HOME="$(getent passwd "$RDP_USERNAME" | cut -d: -f6)"' \
'if [ -z "$USER_HOME" ]; then USER_HOME="/home/$RDP_USERNAME"; fi' \
'mkdir -p "$USER_HOME/.config"' \
'printf "%s\n" "[Default Applications]" "text/html=firefox.desktop" "text/xml=firefox.desktop" "application/xhtml+xml=firefox.desktop" "x-scheme-handler/http=firefox.desktop" "x-scheme-handler/https=firefox.desktop" > "$USER_HOME/.config/mimeapps.list"' \
'printf "%s\n" "#!/bin/sh" "unset DBUS_SESSION_BUS_ADDRESS" "unset XDG_RUNTIME_DIR" "export LANG=C.UTF-8" "export LANGUAGE=C.UTF-8" "export LC_ALL=C.UTF-8" "exec dbus-launch --exit-with-session startxfce4" > "$USER_HOME/.xsession"' \
'chown -R "$RDP_USERNAME:$RDP_USERNAME" "$USER_HOME"' \
'chmod 755 "$USER_HOME/.xsession"' \
'mkdir -p /var/run/xrdp /var/run/xrdp-sesman' \
'rm -f /var/run/xrdp/xrdp.pid /var/run/xrdp/xrdp-sesman.pid' \
'echo "Starting XRDP..."' \
'/usr/sbin/xrdp-sesman' \
'sleep 2' \
'/usr/sbin/xrdp' \
'sleep 2' \
'echo "========================================"' \
'echo "          XRDP IS READY"' \
'echo "========================================"' \
'echo "USERNAME : $RDP_USERNAME"' \
'echo "PASSWORD : $RDP_PASSWORD"' \
'echo "PORT     : 3389"' \
'echo "FIREFOX  : /usr/local/bin/firefox"' \
'echo "WALLPAPER: /usr/share/backgrounds/kali-wallpaper.jpg"' \
'echo "========================================"' \
'pgrep -x xrdp >/dev/null 2>&1 && echo "XRDP     : RUNNING" || echo "XRDP     : FAILED"' \
'pgrep -x xrdp-sesman >/dev/null 2>&1 && echo "SESMAN   : RUNNING" || echo "SESMAN   : FAILED"' \
'test -x /usr/local/bin/firefox && echo "FIREFOX  : INSTALLED" || echo "FIREFOX  : FAILED"' \
'test -f /usr/share/backgrounds/kali-wallpaper.jpg && echo "WALLPAPER: FOUND" || echo "WALLPAPER: NOT FOUND"' \
'echo "========================================"' \
'while true; do sleep 3600; done' \
> /usr/local/bin/start-desktop.sh && \
chmod +x /usr/local/bin/start-desktop.sh

# =========================================================
# RDP PORT
# =========================================================

EXPOSE 3389

# =========================================================
# START
# =========================================================

CMD ["/usr/local/bin/start-desktop.sh"]
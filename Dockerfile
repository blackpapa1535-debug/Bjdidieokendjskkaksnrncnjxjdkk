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
# REAL FIREFOX
# Avoid Ubuntu Snap Firefox
# =========================================================

RUN mkdir -p /opt/firefox && \
    curl -L \
    "https://download.mozilla.org/?product=firefox-latest&os=linux64&lang=en-US" \
    -o /tmp/firefox.tar.bz2 && \
    tar -xjf /tmp/firefox.tar.bz2 \
    --strip-components=1 \
    -C /opt/firefox && \
    rm -f /tmp/firefox.tar.bz2 && \
    ln -sf /opt/firefox/firefox /usr/local/bin/firefox

# =========================================================
# FIREFOX DESKTOP ENTRY
# =========================================================

RUN cat > /usr/share/applications/firefox.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Name=Firefox
GenericName=Web Browser
Comment=Browse the Web
Exec=/usr/local/bin/firefox %u
Icon=/opt/firefox/browser/chrome/icons/default/default128.png
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
EOF

# =========================================================
# DEFAULT BROWSER
# =========================================================

RUN mkdir -p /etc/xdg && \
    cat > /etc/xdg/mimeapps.list <<'EOF'
[Default Applications]
text/html=firefox.desktop
text/xml=firefox.desktop
application/xhtml+xml=firefox.desktop
x-scheme-handler/http=firefox.desktop
x-scheme-handler/https=firefox.desktop

[Added Associations]
text/html=firefox.desktop;
text/xml=firefox.desktop;
application/xhtml+xml=firefox.desktop;
x-scheme-handler/http=firefox.desktop;
x-scheme-handler/https=firefox.desktop;
EOF

# =========================================================
# XRDP
# =========================================================

RUN cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh

unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

export LANG=C.UTF-8
export LANGUAGE=C.UTF-8
export LC_ALL=C.UTF-8

exec dbus-launch --exit-with-session /usr/local/bin/start-xfce.sh
EOF

RUN chmod +x /etc/xrdp/startwm.sh

# =========================================================
# XFCE START + WALLPAPER
# =========================================================

RUN cat > /usr/local/bin/start-xfce.sh <<'EOF'
#!/bin/bash

WALLPAPER="/usr/share/backgrounds/kali-wallpaper.jpg"

# Start XFCE
startxfce4 &
XFCE_PID=$!

# Wait for XFCE desktop
for i in $(seq 1 20); do
    if pgrep -x xfdesktop >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# ---------------------------------------------------------
# Set wallpaper on EVERY detected XFCE monitor/workspace
# ---------------------------------------------------------

if command -v xfconf-query >/dev/null 2>&1; then

    PROPERTIES="$(xfconf-query -c xfce4-desktop -l 2>/dev/null || true)"

    echo "$PROPERTIES" | grep '/last-image$' | while IFS= read -r PROPERTY; do
        if [ -n "$PROPERTY" ]; then
            xfconf-query \
                -c xfce4-desktop \
                -p "$PROPERTY" \
                -s "$WALLPAPER" \
                2>/dev/null || true
        fi
    done

    echo "$PROPERTIES" | grep '/image-style$' | while IFS= read -r PROPERTY; do
        if [ -n "$PROPERTY" ]; then
            xfconf-query \
                -c xfce4-desktop \
                -p "$PROPERTY" \
                -s 5 \
                2>/dev/null || true
        fi
    done

    xfdesktop --reload 2>/dev/null || true
fi

# ---------------------------------------------------------
# Default browser for this XFCE session
# ---------------------------------------------------------

export BROWSER=/usr/local/bin/firefox

if command -v xdg-settings >/dev/null 2>&1; then
    xdg-settings set default-web-browser firefox.desktop 2>/dev/null || true
fi

# Keep XFCE session alive
wait "$XFCE_PID"
EOF

RUN chmod +x /usr/local/bin/start-xfce.sh

# =========================================================
# START DESKTOP
# =========================================================

RUN cat > /usr/local/bin/start-desktop.sh <<'EOF'
#!/bin/bash

set -u

echo "========================================"
echo "     LIGHTWEIGHT XFCE + XRDP"
echo "========================================"

# =========================================================
# YOUR LOGIN
# =========================================================

RDP_USERNAME="desktop"
RDP_PASSWORD="Desktop2026"

# Never use root
if [ -z "$RDP_USERNAME" ] || [ "$RDP_USERNAME" = "root" ]; then
    RDP_USERNAME="desktop"
fi

if [ -z "$RDP_PASSWORD" ]; then
    RDP_PASSWORD="Desktop2026"
fi

echo "Creating user: $RDP_USERNAME"

# =========================================================
# USER
# =========================================================

if ! id "$RDP_USERNAME" >/dev/null 2>&1; then
    useradd \
        --create-home \
        --shell /bin/bash \
        "$RDP_USERNAME"
fi

echo "$RDP_USERNAME:$RDP_PASSWORD" | chpasswd

usermod -aG sudo "$RDP_USERNAME" 2>/dev/null || true

USER_HOME="$(getent passwd "$RDP_USERNAME" | cut -d: -f6)"

if [ -z "$USER_HOME" ]; then
    USER_HOME="/home/$RDP_USERNAME"
fi

mkdir -p "$USER_HOME"

# =========================================================
# USER MIME SETTINGS
# =========================================================

mkdir -p "$USER_HOME/.config"

cat > "$USER_HOME/.config/mimeapps.list" <<'EOF'
[Default Applications]
text/html=firefox.desktop
text/xml=firefox.desktop
application/xhtml+xml=firefox.desktop
x-scheme-handler/http=firefox.desktop
x-scheme-handler/https=firefox.desktop

[Added Associations]
text/html=firefox.desktop;
text/xml=firefox.desktop;
application/xhtml+xml=firefox.desktop;
x-scheme-handler/http=firefox.desktop;
x-scheme-handler/https=firefox.desktop;
EOF

# =========================================================
# XFCE SESSION
# =========================================================

cat > "$USER_HOME/.xsession" <<'EOF'
#!/bin/sh

unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

export LANG=C.UTF-8
export LANGUAGE=C.UTF-8
export LC_ALL=C.UTF-8
export BROWSER=/usr/local/bin/firefox

exec dbus-launch --exit-with-session /usr/local/bin/start-xfce.sh
EOF

chown "$RDP_USERNAME:$RDP_USERNAME" \
    "$USER_HOME/.xsession" \
    "$USER_HOME/.config/mimeapps.list"

chmod 755 "$USER_HOME/.xsession"

# =========================================================
# XRDP DIRECTORIES
# =========================================================

mkdir -p /var/run/xrdp
mkdir -p /var/run/xrdp-sesman

rm -f /var/run/xrdp/xrdp.pid
rm -f /var/run/xrdp/xrdp-sesman.pid

# =========================================================
# START XRDP
# =========================================================

echo "Starting xrdp-sesman..."

/usr/sbin/xrdp-sesman

sleep 2

echo "Starting xrdp..."

/usr/sbin/xrdp

sleep 2

# =========================================================
# STATUS
# =========================================================

echo
echo "========================================"
echo "          XRDP IS READY"
echo "========================================"
echo "USERNAME : $RDP_USERNAME"
echo "PASSWORD : $RDP_PASSWORD"
echo "PORT     : 3389"
echo "BROWSER  : Firefox"
echo "WALLPAPER: Kali Linux"
echo "========================================"

if pgrep -x xrdp >/dev/null 2>&1; then
    echo "XRDP     : RUNNING"
else
    echo "XRDP     : FAILED"
fi

if pgrep -x xrdp-sesman >/dev/null 2>&1; then
    echo "SESMAN   : RUNNING"
else
    echo "SESMAN   : FAILED"
fi

if [ -x /usr/local/bin/firefox ]; then
    echo "FIREFOX  : INSTALLED"
else
    echo "FIREFOX  : FAILED"
fi

if [ -f /usr/share/backgrounds/kali-wallpaper.jpg ]; then
    echo "WALLPAPER: FOUND"
else
    echo "WALLPAPER: NOT FOUND"
fi

echo "========================================"
echo

# Keep container alive
while true; do
    sleep 3600
done
EOF

RUN chmod +x /usr/local/bin/start-desktop.sh

EXPOSE 3389

CMD ["/usr/local/bin/start-desktop.sh"]
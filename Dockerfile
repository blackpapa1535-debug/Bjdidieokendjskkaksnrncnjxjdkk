FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# =====================================================
# LOGIN
# =====================================================

# CHANGE THESE TWO
ENV RDP_USER=desktop
ENV RDP_PASS=Desktop2026

# =====================================================
# PACKAGES
# =====================================================

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
    curl \
    wget \
    ca-certificates \
    nano \
    procps \
    net-tools \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# =====================================================
# WALLPAPER
# =====================================================

COPY kali-wallpaper.jpg /usr/share/backgrounds/kali-wallpaper.jpg

RUN chmod 644 /usr/share/backgrounds/kali-wallpaper.jpg

# =====================================================
# FIREFOX
# =====================================================

RUN mkdir -p /opt/firefox && \
    wget -q \
    "https://download.mozilla.org/?product=firefox-latest&os=linux64&lang=en-US" \
    -O /tmp/firefox.tar.bz2 && \
    tar -xjf /tmp/firefox.tar.bz2 \
    --strip-components=1 \
    -C /opt/firefox && \
    rm -f /tmp/firefox.tar.bz2 && \
    ln -sf /opt/firefox/firefox /usr/local/bin/firefox

# =====================================================
# XRDP STARTUP
# =====================================================

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

# =====================================================
# START DESKTOP
# =====================================================

CMD bash -c '\
set -e; \
echo "========================================"; \
echo "     LIGHTWEIGHT XFCE + XRDP"; \
echo "========================================"; \
\
if [ "$RDP_USER" = "root" ] || [ -z "$RDP_USER" ]; then \
    RDP_USER="desktop"; \
fi; \
\
if [ -z "$RDP_PASS" ]; then \
    RDP_PASS="Desktop2026"; \
fi; \
\
echo "Creating user: $RDP_USER"; \
\
if ! id "$RDP_USER" >/dev/null 2>&1; then \
    useradd -m -s /bin/bash "$RDP_USER"; \
fi; \
\
echo "$RDP_USER:$RDP_PASS" | chpasswd; \
usermod -aG sudo "$RDP_USER" 2>/dev/null || true; \
\
HOME_DIR=$(getent passwd "$RDP_USER" | cut -d: -f6); \
mkdir -p "$HOME_DIR/.config"; \
\
printf "%s\n" \
"#!/bin/sh" \
"unset DBUS_SESSION_BUS_ADDRESS" \
"unset XDG_RUNTIME_DIR" \
"export LANG=C.UTF-8" \
"export LANGUAGE=C.UTF-8" \
"export LC_ALL=C.UTF-8" \
"exec dbus-launch --exit-with-session startxfce4" \
> "$HOME_DIR/.xsession"; \
\
chown "$RDP_USER:$RDP_USER" "$HOME_DIR/.xsession"; \
chmod 755 "$HOME_DIR/.xsession"; \
\
mkdir -p /var/run/xrdp /var/run/xrdp-sesman; \
rm -f /var/run/xrdp/xrdp.pid /var/run/xrdp/xrdp-sesman.pid; \
\
echo "Starting XRDP..."; \
/usr/sbin/xrdp-sesman; \
sleep 2; \
/usr/sbin/xrdp; \
sleep 2; \
\
echo "========================================"; \
echo "          XRDP IS READY"; \
echo "========================================"; \
echo "USERNAME : $RDP_USER"; \
echo "PASSWORD : $RDP_PASS"; \
echo "PORT     : 3389"; \
echo "FIREFOX  : /usr/local/bin/firefox"; \
echo "WALLPAPER: /usr/share/backgrounds/kali-wallpaper.jpg"; \
echo "========================================"; \
\
while true; do \
    sleep 3600; \
done'

EXPOSE 3389
FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update -y && apt install --no-install-recommends -y xfce4 xfce4-goodies tigervnc-standalone-server novnc websockify xrdp sudo xterm init systemd snapd vim net-tools curl wget git tzdata
RUN apt update -y && apt install -y dbus-x11 x11-utils x11-xserver-utils x11-apps
RUN apt install software-properties-common gpg-agent -y
RUN add-apt-repository ppa:mozillateam/ppa -y
RUN echo 'Package: *' >> /etc/apt/preferences.d/mozilla-firefox
RUN echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox
RUN echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox
RUN echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";' | tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox
RUN apt update -y && apt install -y firefox
RUN apt update -y && apt install -y xubuntu-icon-theme
RUN touch /root/.Xauthority
RUN printf '#!/bin/sh\nstartxfce4\n' > /etc/xrdp/startwm.sh && chmod +x /etc/xrdp/startwm.sh
RUN printf 'startxfce4\n' > /root/.xsession
EXPOSE 5901
EXPOSE 6080
EXPOSE 3389
CMD ["bash", "-lc", "set -e; mkdir -p /var/run/xrdp /var/run/xrdp-sesman; vncserver -localhost no -SecurityTypes None -geometry 1024x768 --I-KNOW-THIS-IS-INSECURE; openssl req -new -subj '/C=JP' -x509 -days 365 -nodes -out self.pem -keyout self.pem; websockify -D --web=/usr/share/novnc/ --cert=self.pem 6080 localhost:5901; if ! id rdpuser >/dev/null 2>&1; then useradd -m -s /bin/bash rdpuser; fi; PASS=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 18); echo \\\"rdpuser:$PASS\\\" | chpasswd; printf 'startxfce4\\\\n' > /home/rdpuser/.xsession; chown rdpuser:rdpuser /home/rdpuser/.xsession; /usr/sbin/xrdp-sesman; /usr/sbin/xrdp; echo '================================'; echo \\\"RDP USERNAME: rdpuser\\\"; echo \\\"RDP PASSWORD: $PASS\\\"; echo 'RDP PORT: 3389'; echo '================================'; tail -f /dev/null"]\n
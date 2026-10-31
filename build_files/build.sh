#!/usr/bin/bash
# イメージのビルド中に1回だけ実行されるスクリプト
set -ouex pipefail

OS_NAME="Prism"

### パッケージ
# アシスタントの実行に必要なもの（GTK4 / libadwaita）と、
# Apple 風の見た目に使う GNOME 拡張・フォント・テーマのビルド用ツール
dnf5 install -y --skip-unavailable \
    python3-gobject \
    gtk4 \
    libadwaita \
    pciutils \
    git \
    sassc \
    glib2-devel \
    rsms-inter-fonts \
    google-noto-sans-cjk-fonts \
    gnome-shell-extension-dash-to-dock \
    gnome-shell-extension-blur-my-shell \
    gnome-shell-extension-user-theme \
    gnome-shell-extension-appindicator

### Prism シェル（Hyprland + Quickshell）
# Hyprland は Fedora 公式から外れたため、Hyprland の Wiki が案内している COPR を使う。
# COPR はビルド中だけ有効にする（更新は毎日のイメージ再ビルドで取り込まれる）
# Hyprland 0.57 の COPR は Fedora 44 以降にしかないので、それより古いベースなら止める
if [ "$(rpm -E %fedora)" -lt 44 ]; then
    echo "Prism シェルには Fedora 44 以降のベースが必要です（今は $(rpm -E %fedora)）" >&2
    exit 1
fi
dnf5 -y copr enable lionheartp/Hyprland
dnf5 -y copr enable errornointernet/quickshell
dnf5 install -y \
    hyprland \
    xdg-desktop-portal-hyprland \
    quickshell \
    qt6-qtsvg \
    fcitx5 \
    fcitx5-mozc \
    fcitx5-gtk \
    fcitx5-qt \
    fcitx5-configtool \
    hyprpolkitagent \
    grim \
    slurp \
    wl-clipboard \
    brightnessctl \
    pipewire-utils
dnf5 -y copr disable lionheartp/Hyprland
dnf5 -y copr disable errornointernet/quickshell
chmod +x /usr/libexec/myos-screenshot

### アシスタント（Claude）
# Claude 本体はユーザーごとに入れる Claude Code（サブスクでログイン）を使う。
# ここでは PC 操作ツールを渡す MCP サーバー用のライブラリだけを入れる。
# システムの PyGObject を使えるように --system-site-packages で venv を作る
python3 -m venv --system-site-packages /usr/lib/myos/venv
/usr/lib/myos/venv/bin/pip install --no-cache-dir "mcp>=2,<3"
chmod +x /usr/bin/myos-assistant /usr/bin/myos-claude-code /usr/libexec/myos-firstrun

### Apple 風のテーマ（WhiteSur：オープンソースのテーマ一式）
# ウィンドウ（GTK3）とトップバーのテーマ。信号機の色のウィンドウボタン、すりガラス風のパネル
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/whitesur-gtk
/tmp/whitesur-gtk/install.sh -d /usr/share/themes -c light -c dark -o normal

# アイコン
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git /tmp/whitesur-icons
/tmp/whitesur-icons/install.sh -d /usr/share/icons

# マウスカーソル
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-cursors.git /tmp/whitesur-cursors
cp -r /tmp/whitesur-cursors/dist /usr/share/icons/WhiteSur-cursors

# Prism 独自のアプリアイコン（tools/make_icons.py で作ったもの）。足りないものは WhiteSur を使う
cp /usr/share/icons/Prism/scalable/apps/myos-assistant.svg \
    /usr/share/icons/hicolor/scalable/apps/io.github.myos.Assistant.svg
gtk-update-icon-cache -f /usr/share/icons/Prism || true
gtk-update-icon-cache -f /usr/share/icons/hicolor || true
fc-cache -f

### GNOME の初期設定を反映
# 拡張機能のスキーマがシステム側にない場合はコピーしてから、上書き設定と一緒にコンパイルする
for dir in /usr/share/gnome-shell/extensions/*/schemas; do
    [ -d "$dir" ] || continue
    for schema in "$dir"/*.gschema.xml; do
        [ -e "$schema" ] || continue
        cp -n "$schema" /usr/share/glib-2.0/schemas/
    done
done
glib-compile-schemas /usr/share/glib-2.0/schemas

### OS名
# ID は変えない（Bazzite の更新ツールが参照するため）。表示名だけ変える
sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${OS_NAME} (based on Bazzite)\"/" /usr/lib/os-release

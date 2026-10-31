-- Prism の Hyprland 設定（Hyprland 0.57 以降の Lua 形式）
-- ログイン画面で「Prism」を選ぶと、この設定で起動する。
-- 自分用の追加設定は ~/.config/myos/hyprland-user.lua に書ける（なくてもよい）。
--
-- 書き方が確かでない設定は pcall で囲んである。失敗しても、そこから先の設定が止まらないようにするため。

local mod = "SUPER"
local sounds = "/usr/share/sounds/myos/stereo/"

local function play(name)
    hl.exec_cmd("pw-play " .. sounds .. name .. ".wav")
end

local function exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

---------------------------------------------------------------- 画面

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

---------------------------------------------------------------- 環境変数

hl.env("XCURSOR_THEME", "WhiteSur-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- 日本語入力（fcitx5 + Mozc）
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("SDL_IM_MODULE", "fcitx")

-- NVIDIA の GPU のときだけ設定する（AMD / Intel では逆効果になるため）
local ok, nvidia = pcall(exists, "/proc/driver/nvidia/version")
if ok and nvidia then
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
end

---------------------------------------------------------------- 見た目

hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 12,
        border_size = 0,
        layout = "dwindle",
    },
    decoration = {
        -- rounding_power を上げると、角が円ではなく「なめらかな角丸（スクワークル）」になる
        rounding = 26,
        rounding_power = 4,
        blur = {
            enabled = true,
            size = 10,
            passes = 3,
            noise = 0.02,
            vibrancy = 0.25,
            popups = true,
        },
        shadow = {
            enabled = true,
            range = 40,
            render_power = 3,
            color = 0x33200a50,
        },
    },
    dwindle = {
        preserve_split = true,
    },
    input = {
        kb_layout = "jp",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
        },
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

-- ガラスのウィジェット・フォルダ・Dock の後ろをぼかす（透明な部分はぼかさない）
hl.layer_rule({ match = { namespace = "^myos-(home|dock)$" }, blur = true, ignore_alpha = 0.05 })
-- コントロールセンターは背景全体をぼかす（うすく暗くした面もぼかしの対象にする）
hl.layer_rule({ match = { namespace = "^myos-(control|library)$" }, blur = true, ignore_alpha = 0.0 })

---------------------------------------------------------------- 動き

-- デザインシステムと同じ考え方：開くときはわずかに行き過ぎて戻るスプリング、閉じるときは素早く
hl.curve("myosSpring", { type = "spring", mass = 1, stiffness = 230, damping = 22 })
hl.curve("myosSnappy", { type = "spring", mass = 1, stiffness = 420, damping = 28 })
hl.curve("myosOut", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, spring = "myosSpring", style = "popin 60%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "myosOut", style = "popin 85%" })
hl.animation({ leaf = "windows", enabled = true, speed = 5, spring = "myosSnappy" })
hl.animation({ leaf = "layers", enabled = true, speed = 4, spring = "myosSpring", style = "popin 92%" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "myosOut" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, spring = "myosSpring", style = "slidefade 15%" })

-- タッチパッドの 3 本指スワイプで、開いているアプリを切り替える
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

---------------------------------------------------------------- ウィンドウ

-- アシスタントは画面中央に浮かべる
pcall(function()
    hl.window_rule({ match = { class = "^(io.github.myos.Assistant)$" }, float = true, center = true })
end)

---------------------------------------------------------------- キー操作

hl.bind(mod .. " + C", hl.dsp.exec_cmd("myos-assistant"))
-- Prism シェル（Shortcuts.qml）の操作
pcall(function()
    hl.bind(mod .. " + A", hl.dsp.global("quickshell:controlCenter"))
    hl.bind(mod .. " + L", hl.dsp.global("quickshell:lock"))
    hl.bind(mod .. " + Space", hl.dsp.global("quickshell:apps"))
end)
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("ptyxis"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("nautilus"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())

-- ホーム画面に戻る（何も開いていないワークスペースへ移る）
hl.bind(mod .. " + H", function()
    play("myos-close")
    hl.dispatch(hl.dsp.focus({ workspace = "empty" }))
end)

for i = 1, 5 do
    hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- 音量（変えるたびに小さな音を鳴らす）
hl.bind("XF86AudioRaiseVolume", function()
    hl.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")
    play("audio-volume-change")
end, { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", function()
    hl.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
    play("audio-volume-change")
end, { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })

-- スクリーンショット（Shift を押しながらだと範囲を選ぶ）
hl.bind("Print", hl.dsp.exec_cmd("/usr/libexec/myos-screenshot"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("/usr/libexec/myos-screenshot area"))

-- 書き方を確かめきれていない操作
pcall(function()
    hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
end)
pcall(function()
    hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
end)

---------------------------------------------------------------- 起動時に動かすもの

hl.on("hyprland.start", function()
    -- アプリ（ポータル経由のファイル選択など）が正しく動くよう、環境変数を渡す
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("fcitx5 -d --replace")
    hl.exec_cmd("/usr/libexec/myos-firstrun")
    hl.exec_cmd("qs -p /usr/share/myos/shell")
end)

---------------------------------------------------------------- 自分用の追加設定（任意）

pcall(function()
    require(os.getenv("HOME") .. "/.config/myos/hyprland-user")
end)

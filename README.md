# Prism

Claude を組み込んだ、Apple 風の見た目の自作OSです。
[Bazzite](https://bazzite.gg/)（ゲーム向けの Fedora 派生OS）の GNOME 版をベースにしています。

- **ゲーム**：Steam と Proton で Windows のゲームが動きます（Bazzite の機能をそのまま使います）
- **Claude**：`Super + C` でアシスタントを呼び出せます。質問への回答のほか、アプリを開く、ダークモードに切り替える、PCの状態を調べるといった操作もできます。コマンドを実行するときは、必ず確認ダイアログが出ます
- **見た目**：Apple 風のテーマ（[WhiteSur](https://github.com/vinceliuice/WhiteSur-gtk-theme)）。左上の信号機ボタン、すりガラス風のトップバーと Dock、丸みのあるアイコンとカーソル、オリジナルのグラデーション壁紙（ライト／ダーク）。アシスタントはメッセージアプリ風の青い吹き出し
- **安全性**：システムは読み取り専用です。更新は Fedora / Bazzite から自動で届き、不具合が出たら前のバージョンに戻せます


## ファイル構成

```
Containerfile                 イメージの設計図（ベースイメージの指定）
build_files/build.sh          ビルド時に実行されるスクリプト（パッケージ追加など）
system_files/                 イメージの / にそのままコピーされるファイル
  usr/lib/myos/assistant/     アシスタント本体（Python + GTK4 / libadwaita）
    main.py                     画面
    claude_agent.py             Claude Code（サブスクでログイン）を裏で動かす
    os_tools_server.py          PCを操作するツール（MCP サーバー）
  usr/share/glib-2.0/schemas/ 見た目の初期設定（Dock、アイコン、フォントなど）
  usr/libexec/myos-firstrun   初回ログイン時の設定（Super + C の割り当て）
  usr/share/ublue-os/just/    ujust コマンド（Claude Code のインストールなど）
.github/workflows/build.yml   GitHub で自動ビルドし、ghcr.io に公開する
```

## ビルド（GitHub で自動）

1. このフォルダを GitHub の新しいリポジトリに push する
2. Actions タブで `build` が成功するのを待つ（初回は30分ほどかかります）
3. 以後は毎日自動でビルドされ、最新の Bazzite / Fedora の更新が取り込まれます

ビルドしたイメージは `ghcr.io/<GitHubのユーザー名>/prism:latest` に公開されます。
パッケージの公開範囲が Private になっている場合は、GitHub のパッケージ設定で Public にしてください。

## インストール

1. まず普通の [Bazzite](https://bazzite.gg/) をインストールする（GNOME 版を選ぶ。NVIDIA の GPU なら NVIDIA 版）
2. ターミナルで次のコマンドを実行して、自作イメージに切り替える

   ```bash
   sudo bootc switch ghcr.io/<GitHubのユーザー名>/prism:latest
   ```

3. 再起動する

NVIDIA の GPU を使う場合は、`Containerfile` の `BASE_IMAGE` を `ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable` に変えてからビルドしてください。

### 元に戻す

更新後に不具合が出たら、次のコマンドを実行して再起動すると、1つ前のバージョンに戻ります。

```bash
sudo bootc rollback
```

Bazzite に戻したいときは `sudo bootc switch ghcr.io/ublue-os/bazzite-gnome:stable` を実行します。

## Claude の設定

### アシスタント（Super + C）

アシスタントは、**Claude の Pro / Max プラン**で動きます。APIキーは要りません。

1. 初めて開くと「Claude にログイン」の画面が出るので、「ログイン」を押す
2. ターミナルが開き、Claude Code が自動でインストールされたあと、ブラウザでログイン画面が開く
3. ログインが終わったら、アシスタントの「ログインしました」を押す

仕組み：アシスタントは裏で公式の Claude Code（`claude -p`）を動かしています。
PC を操作するツール（アプリを開く、外観の切り替え、コマンドの実行など）は、
[os_tools_server.py](system_files/usr/lib/myos/assistant/os_tools_server.py) が MCP サーバーとして Claude Code に渡します。
Claude Code 自身のファイル編集やシェルは使わせず、コマンドは必ず確認ダイアログを通します。

- 使った分は、プランの利用上限にカウントされます（Claude Code を使ったときと同じ）
- モデルはプランの既定のものを使います。環境変数 `MYOS_ASSISTANT_MODEL`（例：`opus`、`sonnet`）で変えられます
- ターミナルから `ujust login-claude` でもログインできます

> 自分で使う分には問題ありません。このOSを他の人に配布する場合も、各自が自分のアカウントでログインする形になりますが、
> 公開前に Anthropic の利用規約（サードパーティ製品での Claude ログインの扱い）を確認してください。

### Claude Code

Dock の「Claude Code」を開くと、ターミナルで Claude Code が起動します（初回は自動でインストールされます）。
ターミナルから `ujust install-claude-code` でもインストールできます。

## Prism シェル（タブレット風の画面）

ログイン画面の右下（歯車）で **「Prism」** を選ぶと、タブレット風の画面で起動します。
いつもの GNOME も残っているので、困ったときは「GNOME」を選べば元の画面で使えます。

- 中身：[Hyprland](https://hypr.land/)（画面表示の土台）＋ [Quickshell](https://quickshell.org/)（画面の部品）
- 設定：`system_files/usr/share/myos/hypr/hyprland.lua`（Hyprland 0.57 以降の Lua 形式）
- 画面の部品：`system_files/usr/share/myos/shell/`

| ファイル | 役割 |
|---|---|
| `shell.qml` | 入口。画面ごとに部品を並べる |
| `Home.qml` | ホーム画面（ウィジェット・アプリ・大きなフォルダ・検索） |
| `StatusBar.qml` / `Dock.qml` / `HomeBar.qml` | ステータスバー、Dock、アプリ表示中のホームバー |
| `CalendarWidget.qml` / `ClaudeWidget.qml` / `StatsWidget.qml` / `Folder.qml` | 各ウィジェット |
| `ControlCenter.qml` | コントロールセンター（トグル・音楽・音量・明るさ・ダーク・スクリーンショット・ロック・Claude・電源）と通知の一覧 |
| `Island.qml` | 画面上部の Hyper Island 風の表示（通知・再生中の音楽） |
| `AppLibrary.qml` | すべてのアプリの一覧と検索（長押しでホームに追加） |
| `ClaudeBall.qml` | Claude ボール（画面やコピーした文章をもとに Claude に頼む） |
| `HomeMenu.qml` | アイコン長押し（右クリック）のメニュー。並びは `~/.config/myos/home.json` に保存 |
| `Lock.qml` + `pam/password.conf` | ロック画面（パスワードは PAM で確認） |
| `Theme.qml` / `Sound.qml` / `Apps.qml` / `Stats.qml` | 色と動きの値、効果音、並べるアプリ、PC の数値 |
| `Session.qml` / `Notifs.qml` / `Media.qml` / `Shortcuts.qml` | 画面の状態と電源操作、通知の受け取り、再生中の音楽、キー操作 |

### キー操作

| キー | 動作 |
|---|---|
| Super + C | アシスタント |
| Super + A | コントロールセンター（右上の音量・Wi-Fi を押しても開く） |
| Super + L | ロック（10分さわらなくても自動でロック） |
| Super + Space | すべてのアプリ（ホームの「検索」や Dock の右端からも開く） |
| Super + H | ホーム画面に戻る（画面下のバーを押しても戻れる） |
| Super + Q | アプリを閉じる |
| Super + F | 全画面 |
| Super + Enter / Super + E | ターミナル / ファイル |
| Super + 1〜5 | アプリの切り替え（Shift を足すと、そこへ移動） |
| Print / Shift + Print | スクリーンショット（画面全体 / 範囲） |
| 3本指スワイプ | アプリの切り替え |

日本語入力は fcitx5 + Mozc です（全角／半角キーで切り替え）。

> Hyprland 0.57 の配布パッケージは Fedora 44 以降にしかないため、ベースの Bazzite が Fedora 43 以前だとビルドが止まるようにしてあります。

### まだできていないもの

ドラッグでのアイコン並べ替え（今は長押しメニューで追加・削除のみ）、ホーム画面の2ページ目、画面分割の操作（今は Hyprland の自動分割のみ）。

## デザイン（色・文字・動き・音・アイコン）

| 項目 | 中身 | 作り直し方 |
|---|---|---|
| アイコン | 角丸 22.5%・縦グラデーション・白い記号・上半分のツヤで統一した18種類。`Prism` アイコンテーマとして入り、足りない分は WhiteSur を使う | `tools/make_icons.py` を編集して `python tools/make_icons.py` |
| 壁紙 | 重なるシルクのリボンと光のにじみ（ライト／ダーク） | `system_files/usr/share/backgrounds/myos/*.svg` |
| 効果音 | タップ・トグル・開く／閉じる・通知・完了・注意・スクリーンショット・ログイン・アシスタント | `tools/make_sounds.py` を編集して `python tools/make_sounds.py` |
| 文字 | 英数字 Inter、日本語 Noto Sans CJK JP（`/etc/fonts/local.conf`） | 同ファイル |
| 動き | スプリング（アプリ 520ms、パネル 440ms、トグルは弾む 600ms）、シートは cubic-bezier(0.32, 0.72, 0, 1) | デザイン案の「デザインシステム」ボードが基準。GNOME では細かく変えられないため、独自シェルで実装する |

## カスタマイズ

| 変えたいもの | 場所 |
|---|---|
| 入れるパッケージ | `build_files/build.sh` の `dnf5 install` |
| Dock に並ぶアプリ、見た目の初期値 | `system_files/usr/share/glib-2.0/schemas/zz1-myos.gschema.override` |
| アシスタントができる操作 | `system_files/usr/lib/myos/assistant/claude_agent.py` の `TOOLS` と `HANDLERS` |
| アシスタントの性格・話し方 | 同じファイルの `SYSTEM_PROMPT` |

## 手元でビルドする（任意）

WSL2 や Linux で podman を使ってビルドできます。

```bash
podman build -t prism:latest -f Containerfile .
```

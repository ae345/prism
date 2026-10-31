# Prism 独自のコマンド。`ujust <名前>` で実行する

# Claude Code（ターミナルで使う Claude）をインストールする
install-claude-code:
    #!/usr/bin/bash
    set -euo pipefail
    curl -fsSL https://claude.ai/install.sh | bash
    echo "完了しました。ターミナルで claude と入力すると起動します。"

# Claude に Pro / Max プランのアカウントでログインする（アシスタントもこのログインを使う）
login-claude:
    #!/usr/bin/bash
    set -euo pipefail
    [ -x "$HOME/.local/bin/claude" ] || ujust install-claude-code
    "$HOME/.local/bin/claude" auth login

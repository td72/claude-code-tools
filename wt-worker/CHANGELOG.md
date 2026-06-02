# Changelog

All notable changes to wt-worker will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.1.0] - 2026-06-02

### Added

- `spawn <branch> [<task>]` — ワークツリー + サンドボックスを作成し、Claude Code ワーカーを起動する。`agent-gh-repo-token` が利用可能な場合、リポジトリスコープ付き GitHub トークンを発行してサンドボックスへ注入し、50 分ごとに自動更新するバックグラウンド・リフレッシャーを起動する。`~/.config/wt-worker/config.toml` に宣言したマーケットプレイス・プラグインを読み取り専用ワークスペースとして渡す。
- `tell <branch> <message>` — 指定ブランチのワーカー REPL にメッセージを送信する。
- `logs <branch> [-n <lines>]` — ワーカーペインの出力を取得する（デフォルト: 200 行）。
- `wait <branch> [-t <secs>] [-i <secs>]` — ワーカーが "Worked for" を出力するまでポーリングし、1 ターン完了を検出する。`-t` でタイムアウト秒数、`-i` でポーリング間隔を指定する（デフォルト: 10 秒）。タイムアウト時は exit 1。
- `verify <branch>` — `config.toml` の `[verify].command` をクリーンな Linux コンテナ（デフォルト: `tedsum/claude-code-mise:latest`）内で実行し、CI と同等の環境でテストを回す。`[verify].caches` に宣言したコンテナパスを名前付き Docker ボリュームとして永続化し、繰り返し実行を高速化する。
- `refresh <branch>` — ワーカーのスコープ付き GitHub トークンを手動で再発行する（バックグラウンド・リフレッシャーが停止した場合の復旧用）。
- `cleanup <branch>` — サンドボックスを削除し、ペインを終了し、バックグラウンド・リフレッシャーを停止する。ワークツリーとブランチも削除する。
- `list` — アクティブなサンドボックス一覧を表示する（`sbx ls` のラッパー）。
- `help` — ヘルプを表示する。

[0.1.0]: https://github.com/td72/claude-code-tools/releases/tag/wt-worker-v0.1.0

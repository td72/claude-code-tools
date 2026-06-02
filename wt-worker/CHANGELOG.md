# Changelog

All notable changes to wt-worker will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-06-02

### Added

- `spawn <branch> [<task>]` — `sbx --clone` でインコンテナクローンのサンドボックスを作成し、WezTerm ペインで Claude Code ワーカーを起動する。ブランチ作成・push・PR 作成の指示を自動送信し、バックグラウンドで GitHub トークンを 50 分ごとに自動更新するリフレッシャーも起動する。
- `tell <branch> <message>` — 指定ブランチのワーカー REPL にメッセージを送信する。
- `logs <branch> [-n <lines>]` — ワーカーペインの出力を取得する（デフォルト: 200 行）。
- `wait <branch> [-t <secs>] [-i <secs>]` — ワーカーが "Worked for" を出力するまでポーリングし、1 ターン完了を検知する。`-t` でタイムアウト秒数、`-i` でポーリング間隔を指定できる。
- `verify <branch>` — コミット済みブランチを `git archive` でエクスポートし、クリーンな Linux コンテナ内で `config.toml` の `[verify].command` を実行して CI と同等の環境でテストを回す。
- `refresh <branch>` — ワーカーの GitHub スコープトークンを手動で再発行する（リフレッシャーが停止した場合の手動回復用）。
- `cleanup <branch>` — バックグラウンドリフレッシャーの停止、サンドボックスの削除、WezTerm ペインの終了をまとめて行う。

[Unreleased]: https://github.com/td72/claude-code-tools/compare/wt-worker-v0.1.0...HEAD
[0.1.0]: https://github.com/td72/claude-code-tools/releases/tag/wt-worker-v0.1.0

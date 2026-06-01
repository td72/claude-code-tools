# claude-code-tools

Claude Code の **司令塔 / worker** 並列開発を支援するプラグインを配布する marketplace。

## プラグイン一覧

| プラグイン | 概要 |
|---|---|
| [`wt-worker`](./wt-worker/) | git worktree 単位で Docker Sandboxes (sbx) を切り、WezTerm pane に worker Claude を立ち上げる |

各プラグインの前提ツール・セットアップ・使い方は、それぞれの README を参照してください。

## インストール

```text
/plugin marketplace add td72/claude-code-tools
/plugin install wt-worker@td72
```

一度インストールすると以降のセッションで自動ロードされます。

## 開発

```bash
mise install    # shellcheck / hadolint / jq / yq を固定バージョンで導入
mise run lint   # 全プラグインの lint
```

各プラグイン固有のタスク (`mise run wt-worker:*` など) は、そのプラグインの README を参照。

## ライセンス

MIT (see `LICENSE`).
<!-- m1-probe -->

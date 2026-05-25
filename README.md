# claude-code-tools

Claude Code の **司令塔 / worker** 並列開発を支援するプラグイン集。

## プラグイン一覧

| プラグイン | 概要 |
|---|---|
| [`wt-worker`](./wt-worker/) | git worktree 単位で Docker Sandboxes (sbx) を切り、WezTerm pane に worker Claude を立ち上げる |

---

## wt-worker

**wt** = **W**ork**T**ree × **W**ez**T**erm。  
ブランチごとに独立した sbx サンドボックスを作り、WezTerm pane で worker Claude を走らせるプラグイン。

設計の詳細は [`wt-worker/docs/worktree-workflow.md`](./wt-worker/docs/worktree-workflow.md) を参照。

### 前提ツール

| ツール | 用途 |
|---|---|
| `wezterm` (cli) | pane の split / send-text / get-text |
| `sbx` | Docker Sandboxes CLI (認証・サンドボックス管理・worktree 作成) |
| `mise` | ツールチェイン (shellcheck / hadolint / jq / yq をこの repo で固定) |

`mise install` で shellcheck / hadolint / jq / yq が揃います。wezterm と sbx はホストに別途。

### 初回セットアップ

```bash
# Anthropic 認証 (1 回だけ)
sbx secret set anthropic

# GitHub 認証 (1 回だけ; worker が git push / gh を叩く場合)
sbx secret set github
# → GitHub fine-grained PAT を入力
#   必要スコープ: contents:write + pull_requests:write (対象リポジトリのみ)
```

認証はすべて sbx プロキシが透過処理するため、コンテナ内に token が露出しません。

### インストール — Claude Code plugin として

```text
/plugin marketplace add td72/claude-code-tools
/plugin install wt-worker@td72
```

一度インストールすると以降のセッションで自動ロードされます。

ローカル開発時にディレクトリを直接読みたい場合:

```bash
claude --plugin-dir /path/to/claude-code-tools/wt-worker
```

### 使い方 — Bash CLI

```bash
# worker を spawn (worktree + pane + sbx sandbox + claude REPL)
wt-worker spawn feature/foo "実装タスクの説明"

# 追加指示を送る
wt-worker tell feature/foo "PR を作成してください"

# worker pane の末尾を読む (デフォルト 200 行)
wt-worker logs feature/foo
wt-worker logs feature/foo -n 50

# 起動中のサンドボックス一覧
wt-worker list

# 片付け (sandbox + worktree + pane をまとめて削除)
wt-worker cleanup feature/foo
```

### 使い方 — Claude Code plugin として

```text
/wt-worker:spawn feature/foo "実装タスクの説明"
/wt-worker:tell  feature/foo "PR を作成してください"
/wt-worker:logs  feature/foo
/wt-worker:list
/wt-worker:cleanup feature/foo
```

> `disable-model-invocation: true` が設定されているため、司令塔 Claude が自動で spawn することはありません。

### worktree の場所

`wt-worker spawn` は `sbx --branch` を使い、worktree を次のパスに作成します:

```
<repo-root>/.sbx/wt-worker-<branch>-worktrees/<branch-sanitized>/
```

`.sbx/` は `.gitignore` に追加しておいてください:

```bash
echo '.sbx/' >> .gitignore
```

### worker への plugin 引き継ぎ

ホストにインストール済みの plugin を worker にも渡したい場合、`~/.config/wt-worker/config.toml` に列挙します:

```toml
[[marketplaces]]
name    = "kiconia-plugins"
plugins = ["mise", "uv"]

[[marketplaces]]
name    = "claude-plugins-official"
plugins = ["github"]
```

`wt-worker spawn` 時に自動で read-only マウントされ `claude --plugin-dir` で渡されます。  
config 不在 / `yq`/`jq` 不在 / plugin 未インストール — いずれも spawn は abort せず、その plugin だけスキップします。

設定ファイルの雛形: [`wt-worker/examples/config.toml`](./wt-worker/examples/config.toml)

### 開発 (mise tasks)

```bash
# wt-worker のみ
mise run wt-worker:lint    # hadolint Dockerfile + shellcheck bin/wt-worker
mise run wt-worker:build   # docker image build (tedsum/claude-code-mise)
mise run wt-worker:push    # build & push to Docker Hub
mise run wt-worker:shell   # built image で bash を開く
mise run wt-worker:verify  # mise インストール確認
mise run wt-worker:ci      # lint + build (CI 用)

# 全プラグインまとめて
mise run lint
```

## ライセンス

MIT (see `LICENSE`).

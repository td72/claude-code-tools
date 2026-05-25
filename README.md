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

| ツール | 用途 | 必須? |
|---|---|---|
| `wezterm` (cli) | pane の split / send-text / get-text | 必須 |
| `sbx` | Docker Sandboxes CLI (認証・サンドボックス管理・worktree 作成) | 必須 |
| `mise` | ツールチェイン (shellcheck / hadolint / jq / yq をこの repo で固定) | 必須 |
| `uv` | `wt-worker-gh-token` の inline-deps 解決 | GitHub App 機能を使う場合 |
| `op` (1Password CLI) | App private key / installation_id 等の引き出し | GitHub App 機能を使う場合 |

`mise install` で shellcheck / hadolint / jq / yq が揃います。wezterm / sbx / uv / op はホストに別途。

### 初回セットアップ

```bash
# Anthropic 認証 (1 回だけ)
sbx secret set anthropic
```

GitHub 認証は 2 通りから選べます。

**(A) ざっくり: グローバル PAT を 1 つ置く** — 個人用途で他人と共有しないなら最短:

```bash
sbx secret set -g github
# → GitHub fine-grained PAT を入力
#   必要スコープ: contents:write + pull_requests:write (対象リポジトリのみ)
```

**(B) 推奨: GitHub App + 1Password で per-repo の最小権限 token を毎回発行** —
worker ごとに「その repo だけ・必要な permission だけ・1時間で失効」の token を mint:

```bash
# 1. GitHub App を作成 (https://github.com/settings/apps/new)
#    Permissions: Contents=Write, Pull requests=Write
#    Webhook: 無効化
#    Where can this GitHub App be installed?: Only on this account
# 2. App の private key (.pem) を生成・ダウンロード
# 3. 対象 repo に install
# 4. 1Password に item を作って下記フィールドを保存:
#      app_id           = <App ID>
#      installation_id  = <Installation ID>
#      private_key      = <PEM 全体>
# 5. ~/.config/wt-worker/repos.toml を書く
cp wt-worker/examples/repos.toml ~/.config/wt-worker/repos.toml
$EDITOR ~/.config/wt-worker/repos.toml
```

`wt-worker spawn` が呼ばれたとき、(B) があれば sandbox 固有 secret として
scoped token が自動 inject されます。なければ (A) の global secret が fallback。

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

### per-repo GitHub App token (上記初回セットアップ B の詳細)

`~/.config/wt-worker/repos.toml` に org/repo → 1Password item のマッピングを書きます:

```toml
["github.com/td72"]
op_item     = "op://Personal/td72-wt-worker"
permissions = { contents = "write", pull_requests = "write" }

# 例外だけ書く (org 設定が deep merge のベース)
["github.com/td72/secret-stuff"]
permissions = { contents = "read", pull_requests = "write" }
```

resolve 規則:

1. `["github.com/<owner>/<repo>"]` があればその値
2. なければ `["github.com/<owner>"]` の値
3. repo は org を per-key で上書き (shallow merge)
4. どちらも無ければ skip (warning, spawn は続行)

token は API 呼び出し時に `repositories=[<現在の repo>]` + `permissions=<上記>` で
絞られるため、install が複数 repo に効いていても worker は**この repo だけ**触れます。

設定ファイルの雛形: [`wt-worker/examples/repos.toml`](./wt-worker/examples/repos.toml)

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

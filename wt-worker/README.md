# wt-worker

**wt** = **W**ork**T**ree × **W**ez**T**erm。  
ブランチごとに独立した sbx サンドボックスを作り、WezTerm pane で worker Claude を走らせる Claude Code プラグイン。git worktree 単位で Docker Sandboxes (sbx) を切り、WezTerm pane に worker Claude を立ち上げて、司令塔 Claude から並列に開発を進めます。

設計の詳細は [`docs/worktree-workflow.md`](./docs/worktree-workflow.md) を参照。

## 前提ツール

| ツール | 用途 | 必須? |
|---|---|---|
| `wezterm` (cli) | pane の split / send-text / get-text | 必須 |
| `sbx` | Docker Sandboxes CLI (認証・サンドボックス管理・worktree 作成) | 必須 |
| `mise` | ツールチェイン (shellcheck / hadolint / jq / yq をこの repo で固定) | 必須 |
| [`agent-gh-repo-token`](https://github.com/td72/agent-gh-repo-token) | per-repo の scoped GitHub token を mint | GitHub App 認証を使う場合 |

`mise install` で shellcheck / hadolint / jq / yq が揃います。wezterm / sbx はホストに別途。

## 初回セットアップ

```bash
# Anthropic 認証 (1 回だけ、global)
sbx secret set -g anthropic
```

GitHub 認証は 2 通りから選べます。

**(A) ざっくり: グローバル PAT を 1 つ置く** — 個人用途で他人と共有しないなら最短:

```bash
sbx secret set -g github
# → GitHub fine-grained PAT を入力
#   必要スコープ: contents:write + pull_requests:write (対象リポジトリのみ)
```

**(B) 推奨: per-repo の最小権限 token を毎回発行** —
[`agent-gh-repo-token`](https://github.com/td72/agent-gh-repo-token) をホストに入れ、
GitHub App + 1Password で「その repo だけ・必要な permission だけ・1時間で失効」の token を mint:

```bash
# install スクリプト (OS/arch 自動判定 → sha256 検証 → /usr/local/bin)
curl -fsSL https://raw.githubusercontent.com/td72/agent-gh-repo-token/main/scripts/install.sh | sh
# または: go install github.com/td72/agent-gh-repo-token@latest

# セットアップ手順 (App 作成 → install → 1Password に保存 → repos.toml を書く)
# は agent-gh-repo-token の README を参照
```

`wt-worker spawn` が呼ばれたとき、`agent-gh-repo-token` が PATH にあり repos.toml に
該当 entry があれば、sandbox 固有 secret として scoped token が自動 inject されます。
なければ (A) の global secret が fallback。

認証はすべて sbx プロキシが透過処理するため、コンテナ内に token が露出しません。

## インストール — Claude Code plugin として

```text
/plugin marketplace add td72/claude-code-tools
/plugin install wt-worker@td72
```

一度インストールすると以降のセッションで自動ロードされます。

ローカル開発時にディレクトリを直接読みたい場合:

```bash
claude --plugin-dir /path/to/claude-code-tools/wt-worker
```

## 使い方 — Bash CLI

```bash
# worker を spawn (worktree + pane + sbx sandbox + claude REPL)
wt-worker spawn feature/foo "実装タスクの説明"

# 追加指示を送る
wt-worker tell feature/foo "PR を作成してください"

# worker pane の末尾を読む (デフォルト 200 行)
wt-worker logs feature/foo
wt-worker logs feature/foo -n 50

# コミット済みブランチを CI パリティのクリーンコンテナでテスト
# (config.toml の [verify] が必要。e2e など native 依存タスクの検証用)
wt-worker verify feature/foo

# worker の branch をホスト側から origin へ push (SSH 経由)
# .github/workflows を変更する branch 用の人間ゲート付き経路。
# 読み取り(preview-push)と実push(push)を別コマンドに分け、push 側を
# .claude/settings.json の `ask` で毎回プロンプト＝人間ゲートにしている。
wt-worker preview-push feature/foo   # diff を表示するだけ (自由に実行可)
wt-worker push feature/foo           # 実 push (許可プロンプトが出る)

# 起動中のサンドボックス一覧
wt-worker list

# 片付け (sandbox + worktree + pane をまとめて削除)
wt-worker cleanup feature/foo
```

## 使い方 — Claude Code plugin として

```text
/wt-worker:spawn feature/foo "実装タスクの説明"
/wt-worker:tell  feature/foo "PR を作成してください"
/wt-worker:logs  feature/foo
/wt-worker:verify feature/foo
/wt-worker:push  feature/foo   # preview-push で diff 確認 → push (許可プロンプト)
/wt-worker:list
/wt-worker:cleanup feature/foo
```

> `disable-model-invocation: true` が設定されているため、司令塔 Claude が自動で spawn することはありません。

## worker の作業空間 (in-container clone)

`wt-worker spawn` は `sbx --clone` を使い、worker を**コンテナ内のプライベートクローン**で動かします（ホスト repo は read-only マウント、ホスト側 worktree は作りません）。クローンはホストの `origin` を引き継ぐため、worker は **`git push origin <branch>` でそのまま GitHub に push** できます（spawn が ssh→https の書き換えと token 注入を仕込むため）。worker の commit はセッション稼働中、ホストから `sandbox-<name>` remote 経由でも参照できます。

```
ホスト repo (RO) ──clone──▶ コンテナ内 /home/agent/workspace (worker の作業空間)
                              └─ origin = GitHub (https に書き換え) → push/PR は worker が直接
```

> 旧 sbx の `--branch`（`.sbx/` 下にホスト worktree を作る方式）は廃止されました。

### `.github/workflows` を変更する branch（ホスト側 push の人間ゲート）

worker の scoped token は意図的に `workflows` スコープを持たないため、`.github/workflows/*` を
変更するコミットの push は GitHub に拒否される（CI = secrets 付き任意コード実行なので、半自律
エージェントに常設で渡さない最小権限の設計）。この場合 worker は**リトライせず停止・報告**し、
司令塔がホスト側から SSH で push する。読み取り（`wt-worker preview-push`）と実 push
（`wt-worker push`）を別コマンドに分け、`push` 側を `.claude/settings.json` の `ask` で
**毎回許可プロンプト**にすることで、CI 改変の前に人間が必ず diff を確認する導線を権限レイヤで
強制している。詳細は [`docs/worktree-workflow.md` の「8. Push」](./docs/worktree-workflow.md)。

## worker への plugin 引き継ぎ

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

設定ファイルの雛形: [`examples/config.toml`](./examples/config.toml)

## per-repo GitHub App token (初回セットアップ B の詳細)

GitHub App 作成・1Password へのキー保管・`repos.toml` の書き方は
[agent-gh-repo-token の README](https://github.com/td72/agent-gh-repo-token)
を参照してください。

wt-worker 側の挙動: spawn 時に `git remote get-url origin` から `host/owner/repo` を
導出し、`agent-gh-repo-token --repo <それ>` を呼びます。stdout に token が返れば
`sbx secret set <sandbox名> github` で sandbox 固有 secret として注入、失敗・skip した
場合はグローバル secret 任せで spawn を続行します。

token は 1 時間で失効するため、spawn と同時に background refresher を `nohup` で
起動し、50 分ごとに再 mint して上書きします (ターミナルを閉じても生存)。
`wt-worker cleanup` 時に SIGTERM で停止、`wt-worker refresh <branch>` で手動再 mint も可能。

## 開発 (mise tasks)

```bash
mise run wt-worker:lint    # hadolint Dockerfile + shellcheck bin/wt-worker
mise run wt-worker:build   # docker image build (tedsum/claude-code-mise)
mise run wt-worker:push    # build & push to Docker Hub
mise run wt-worker:shell   # built image で bash を開く
mise run wt-worker:verify  # mise インストール確認
mise run wt-worker:ci      # lint + build (CI 用)
```

## ライセンス

MIT — リポジトリルートの [LICENSE](../LICENSE) を参照。

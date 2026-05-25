# claude-code-tools

Claude Code の **司令塔 / worker** 並列開発を支援する小道具集。

- **`ccwt`** — git worktree 単位で [Docker Sandboxes (sbx)](https://docs.docker.com/ai/gordon/docker-sandboxes/) を切り、WezTerm pane に worker Claude を立ち上げる Bash CLI。Claude Code plugin としても利用可能 (`/ccwt:spawn` 等)。

設計の全体像は [`docs/worktree-workflow.md`](docs/worktree-workflow.md) を参照。

## 前提ツール

| ツール | 用途 |
|---|---|
| `wezterm` (cli) | pane の split / send-text / get-text |
| `sbx` | Docker Sandboxes CLI (認証・サンドボックス管理) |
| `gwq` | worktree 管理 (`~/worktrees/...` 配下) |
| `mise` | tool chain (gwq, shellcheck, yq, jq をこの repo で固定) |

`mise install` で gwq / shellcheck / yq / jq が揃います。wezterm と sbx はホストに別途。

## 初回セットアップ

```bash
# sbx の認証を設定 (1 回だけ)
sbx secret set anthropic
```

これで `ccwt spawn` 時の worker 認証が自動で処理されます。

## 使い方 — Bash CLI として

```bash
# ツールを入れる
mise install

# bin/ を PATH に通すため mise 環境下に入るか、mise exec を経由する
mise exec -- ccwt help

# 司令塔登録 (現在の WezTerm pane を commander として記録)
mise exec -- ccwt init

# worker を spawn (worktree + pane + sbx sandbox + claude REPL)
mise exec -- ccwt spawn feature/foo "<initial task>"

# 追加指示
mise exec -- ccwt tell feature/foo "<message>"

# 一覧
mise exec -- ccwt list

# 片付け (sandbox + pane を落とす; worktree は残る)
mise exec -- ccwt cleanup feature/foo
mise exec -- gwq remove feature/foo   # 不要なら worktree も削除
```

## 使い方 — Claude Code plugin として

司令塔 Claude に slash command (`/ccwt:spawn` 等) として読み込ませる場合、marketplace 経由で永続インストールします:

```text
# 一度だけ
/plugin marketplace add td72/claude-code-tools
/plugin install ccwt@td72

# 以降のセッションでは自動でロードされる
/ccwt:init
/ccwt:spawn feature/foo "<task>"
/ccwt:tell  feature/foo "<message>"
/ccwt:list
/ccwt:cleanup feature/foo
```

開発中にローカルディレクトリを直接読みたい場合は:

```bash
claude --plugin-dir /path/to/claude-code-tools
```

`disable-model-invocation: true` を付けてあるので、明示的に `/ccwt:*` と叩いたときだけ動きます (司令塔 Claude が勝手に spawn することはありません)。

## worker への plugin 引き継ぎ

ホストの Claude にインストール済みの plugin (たとえば `kiconia-plugins/mise` や `claude-plugins-official/github`) を worker にも引き継ぎたい場合、`~/.config/ccwt/config.toml` に列挙しておくと `ccwt spawn` 時に自動で読み取って sbx の追加 workspace として read-only マウントし、`claude --plugin-dir` で渡します。

設定ファイルの最小例は [`examples/config.toml`](examples/config.toml) を参照。書式:

```toml
[[marketplaces]]
name    = "kiconia-plugins"
plugins = ["mise", "uv"]

[[marketplaces]]
name    = "claude-plugins-official"
plugins = ["github"]
```

config が無い、`yq`/`jq` が無い、もしくはローカルに該当 plugin が未インストール — どのケースでも `ccwt spawn` は abort せず、その plugin だけスキップして素の worker を起動します。

## 開発

```bash
mise run lint    # hadolint Dockerfile + shellcheck bin/ccwt
mise run build   # docker image build (tedsum/claude-code-mise)
mise run push    # build & push to Docker Hub
```

## ライセンス

MIT (see `LICENSE`).

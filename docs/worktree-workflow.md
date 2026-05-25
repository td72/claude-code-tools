# Worktree × Sandbox 並列開発ワークフロー

## ゴール

- 1 つの WezTerm ウィンドウ内で、**司令塔 claude** と **複数の worker claude** が共存する開発スタイルを定義する
- 各 worker は独立した git worktree と Docker Sandboxes (sbx) 上で動作し、ホスト環境や他 worker と隔離される
- 司令塔は worker pane を観察し、必要に応じて wezterm 経由で追加指示を投入できる
- 本体リポジトリ (`~/src/...`) のクローン位置を汚さない

## 非ゴール

- worker 同士の直接 IPC（git の commit / branch 越しに間接通信する）
- マルチホスト分散、リモート CI への展開
- 自動マージ（最終マージは人間または司令塔の判断）
- tmux / 他ターミナル対応（WezTerm 専用）

## アーキテクチャ概要

```
+-------------------- WezTerm Window --------------------+
|  司令塔 claude (host)                                  |
|  $ ccwt spawn feature-x "<initial task>"               |
+--------------------------------------------------------+
|  worker A (sbx sandbox → claude REPL, branch=feature-x)|
|  > implement ...                                       |
+--------------------------------------------------------+
|  worker B (sbx sandbox → claude REPL, branch=feature-y)|
|  > implement ...                                       |
+--------------------------------------------------------+
```

### 司令塔 (Commander)

- ホスト OS 上の claude code セッション
- `ccwt` CLI を叩いて worker のライフサイクルを管理
- worker pane を `wezterm cli get-text` で覗き、`wezterm cli send-text` で追加指示を投入
- worker のブランチをレビュー・マージ

### Worker

- Docker Sandboxes (sbx) 上で動く claude REPL（対話モード）
- worktree ディレクトリだけがマウントされ、他リポジトリやホスト全体には触れない
- 出力は wezterm pane に流れ、人間と司令塔の双方が観察できる

### 通信

| 方向 | 手段 |
|---|---|
| 司令塔 → worker | `wezterm cli send-text --pane-id <id>` で REPL に投入 |
| worker → 司令塔 | git commit / branch（pull 経由で間接的に伝達） |
| 完了の伝達 | 司令塔が pane を `get-text` で覗いて判断、または人間が口頭で司令塔に伝える |

## ディレクトリレイアウト

```
~/src/github.com/td72/<repo>/         # 司令塔が動く本体
~/worktrees/github.com/td72/<repo>/   # gwq が管理する worktree 群
  ├─ feature-x/                        # worker A の作業空間
  └─ feature-y/                        # worker B の作業空間

~/.local/state/ccwt/<repo>/           # 司令塔のローカル状態 (XDG 準拠)
  ├─ commander                         # 司令塔自身の pane-id
  └─ panes/<branch>                    # branch ごとの WezTerm pane-id
```

## 前提ツール

| ツール | 用途 | 入手 |
|---|---|---|
| `gwq` | worktree の add / list / get / remove | `mise.toml` の `[tools]` |
| `wezterm` (cli) | pane の split / send-text / get-text | ホストに既存 |
| `sbx` | Docker Sandboxes CLI (sandbox 作成・認証・ライフサイクル) | ホストに既存 |

## ライフサイクル

### 0. Init

```bash
ccwt init
```

- 現在の WezTerm pane-id (`$WEZTERM_PANE`) を `~/.local/state/ccwt/<repo>/commander` に保存

### 1. Spawn

```bash
ccwt spawn <branch> ["<initial-task>"]
```

実行手順:

1. `gwq add [-b] <branch>` で worktree を作成（パスは `~/worktrees/github.com/<owner>/<repo>/<branch>/`）
2. `sbx create --name ccwt-<branch> claude <worktree> [plugin_dirs:ro...]` でサンドボックスを作成
3. `wezterm cli split-pane --bottom` で司令塔の下に pane を追加し、pane-id を保存
4. pane 内で `sbx run ccwt-<branch> [-- --plugin-dir ...]` を実行して REPL に入る
5. `<initial-task>` が指定されていれば、続けて pane に送信

認証は sbx プロキシが透過的に処理します（`sbx secret set anthropic` で事前設定）。

### 2. 追加指示

```bash
ccwt tell <branch> "<message>"
```

- `~/.local/state/ccwt/<repo>/panes/<branch>` から pane-id を読み出し
- `wezterm cli send-text --pane-id <id> "<message>"` で投入
- claude REPL は Enter で送信されるため、末尾に CR を別送する

### 3. 完了検知

対話モードでは「タスクが終わった」を機械的に判定する確実な方法がない。シンプルに以下のみで運用:

- **pane 観察**: 司令塔が必要に応じて `wezterm cli get-text --pane-id <id> --start-line -200` で末尾を読む
- **人間判断**: 最終確認は人間が pane を見て行う

### 4. Cleanup

```bash
ccwt cleanup <branch>
```

1. `sbx rm ccwt-<branch>` でサンドボックスを削除
2. `wezterm cli kill-pane --pane-id <id>` で pane を削除
3. pane-id ファイルを削除
4. `gwq remove <branch>` は手動（未コミット変更があれば人間が判断）

### 5. その他コマンド

| コマンド | 用途 |
|---|---|
| `ccwt list` | `sbx ls` + `gwq list` で起動中の sandbox と worktree を表示 |

## WezTerm 連携の詳細

### pane 作成

```bash
PANE_ID=$(wezterm cli split-pane \
  --bottom --percent 30 \
  --pane-id "$(cat ~/.local/state/ccwt/<repo>/commander)" \
  --cwd "$WORKTREE_PATH")
```

### テキスト投入

```bash
wezterm cli send-text --no-paste --pane-id "$PANE_ID" "$MESSAGE"
printf '\r' | wezterm cli send-text --no-paste --pane-id "$PANE_ID"
```

### 出力取得

```bash
wezterm cli get-text --pane-id "$PANE_ID" --start-line -200
```

## worker への plugin 引き継ぎ

`~/.config/ccwt/config.toml` に列挙した plugin を、`ccwt spawn` 時に sbx の追加 workspace として read-only マウントし `claude --plugin-dir` で渡します。

```toml
[[marketplaces]]
name    = "kiconia-plugins"
plugins = ["mise", "uv"]

[[marketplaces]]
name    = "claude-plugins-official"
plugins = ["github"]
```

### 解決ルール

各 (marketplace, plugin) ペアについて:

1. `~/.claude/plugins/cache/<marketplace>/<name>/` 配下を `ls | sort -V | tail -1` で最新ディレクトリに解決
2. `sbx create` に追加 workspace として `:ro` で渡す（ホストと同じパスでマウントされる）
3. `sbx run` に `-- --plugin-dir <host_path>` を追加

config 不在、`yq`/`jq` 不在、plugin 未インストール — いずれも spawn は abort せず、その plugin だけスキップ。

## 認証

sbx プロキシが API 認証を透過的に処理するため、worker に認証情報を手動で渡す必要はありません。

```bash
# ホストで 1 回だけ設定
sbx secret set anthropic
```

worker 内の claude が Anthropic API を呼ぶと、sbx プロキシが自動で認証を注入します。rate limit はホストと worker で共有プールになります。

## オープン課題

1. **pane が増えすぎた場合**: 一定数を超えたら自動で tab に切り替える等の拡張は将来検討
2. **依存関係のある worker**: worker B が worker A の成果物に依存するケースは MVP のスコープ外（人間が `git merge` してから B を spawn）

## 関連

- `mise.toml`: ツールチェイン管理
- gwq: <https://github.com/d-kuro/gwq>
- Docker Sandboxes: <https://docs.docker.com/ai/gordon/docker-sandboxes/>
- WezTerm CLI: <https://wezfurlong.org/wezterm/cli/general.html>

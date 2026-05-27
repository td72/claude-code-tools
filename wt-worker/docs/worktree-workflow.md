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
|  $ wt-worker spawn feature-x "<initial task>"          |
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
- `wt-worker` CLI を叩いて worker のライフサイクルを管理
- worker pane を `wezterm cli get-text` で覗き、`wezterm cli send-text` で追加指示を投入
- worker のブランチをレビュー・マージ・PR 化

### Worker

- Docker Sandboxes (sbx) 上で動く claude REPL（対話モード）
- ホスト OS には触れない (sbx の隔離境界内で動作)
- 出力は wezterm pane に流れ、人間と司令塔の双方が観察できる

### 通信

| 方向 | 手段 |
|---|---|
| 司令塔 → worker | `wezterm cli send-text --pane-id <id>` で REPL に投入 |
| worker → 司令塔 | git commit / branch / PR (pull 経由で間接的に伝達) |
| 完了の伝達 | 司令塔が pane を `get-text` で覗いて判断、または人間が確認 |

## ディレクトリレイアウト

```
~/src/github.com/td72/<repo>/                       # 司令塔が動く本体
  └─ .sbx/                                          # sbx が管理 (gitignore 推奨)
       └─ wt-worker-<branch>-worktrees/<branch>/    # worker A の作業空間
                                                    #  (sbx --branch が自動生成)

~/.local/state/wt-worker/<repo>/                    # 司令塔のローカル状態 (XDG 準拠)
  ├─ panes/<branch>                                 # branch ごとの WezTerm pane-id
  ├─ repos/<branch>                                 # branch → host/owner/repo の memo (refresh 用)
  └─ refreshers/<branch>.{pid,log}                  # background refresher の PID とログ
```

## 前提ツール

| ツール | 用途 | 必須? |
|---|---|---|
| `wezterm` (cli) | pane の split / send-text / get-text | 必須 |
| `sbx` | sandbox 作成 / 認証 / `--branch` で worktree 作成 | 必須 |
| [`agent-gh-repo-token`](https://github.com/td72/agent-gh-repo-token) | per-repo の scoped GitHub token を mint | GitHub App 使用時 |
| `op` (1Password CLI) | App private key 等の引き出し (agent-gh-repo-token が使用) | GitHub App 使用時 |

## ライフサイクル

### 1. Spawn

```bash
wt-worker spawn <branch> ["<initial-task>"]
```

実行手順:

1. `$WEZTERM_PANE` を司令塔の pane-id として記録
2. `sbx create --branch=<branch> --name wt-worker-<branch> claude <toplevel> [plugin_dirs:ro...]`
   - sbx が worktree を `<toplevel>/.sbx/<sandbox名>-worktrees/<branch>/` に作る
3. `~/.config/agent-gh-repo-token/repos.toml` があれば GitHub App token を mint し、
   `sbx secret set <sandbox名> github` で sandbox 固有 secret として注入 (best-effort)
4. `wezterm cli split-pane --bottom --percent 30` で司令塔の下に pane を追加し、pane-id を保存
5. pane 内で `sbx run <sandbox名> [-- --plugin-dir ...]` を実行して REPL に入る
6. `<initial-task>` が指定されていれば、`sleep` 後にその文字列を pane に送信

認証は sbx プロキシが透過的に処理します (詳細は下「認証」セクション)。

### 2. 追加指示

```bash
wt-worker tell <branch> "<message>"
```

- `~/.local/state/wt-worker/<repo>/panes/<branch>` から pane-id を読み出し
- `wezterm cli send-text --pane-id <id> "<message>"` で投入
- claude REPL は Enter で送信されるため、末尾に CR を別送する

### 3. 出力の覗き見

```bash
wt-worker logs <branch> [-n <lines>]
```

`wezterm cli get-text --pane-id <id> --start-line -<lines>` で末尾を読む (デフォルト 200 行)。

### 4. 完了検知

対話モードでは「タスクが終わった」を機械的に判定する確実な方法がない。シンプルに以下のみで運用:

- **pane 観察**: 司令塔が必要に応じて `wt-worker logs` で末尾を読む (Claude Code が `✻ Worked for ...` を出した時点で 1 ターンが終わったサイン)
- **git 監視**: 新しい commit が来たら「実装は進んだ」とみなす
- **人間判断**: 最終確認は人間が pane を見て行う

### 5. Token refresh (自動 / 手動)

`agent-gh-repo-token` を使った scoped token は **1 時間で失効**するため、
`wt-worker spawn` は同時に背景プロセス (refresher) を `nohup` で起動します:

- 50 分ごとに `agent-gh-repo-token --repo <...>` を再実行し、新 token を
  `sbx secret set <sandbox> github` で上書き
- `sbx secret ls <sandbox>` で sandbox の生存を確認、消えていたら自己終了
- ログ: `~/.local/state/wt-worker/<repo>/refreshers/<branch>.log`
- PID: `~/.local/state/wt-worker/<repo>/refreshers/<branch>.pid`

ターミナルを閉じても `nohup` で生き残ります (ただしホスト再起動は越えない)。
何らかの理由で refresher が死んだ・再起動後すぐ更新したい場合は手動で:

```bash
wt-worker refresh <branch>   # 一度だけ再 mint して secret を上書き
```

interval は `WT_WORKER_REFRESH_INTERVAL` (秒) で変更可能 (デフォルト 3000)。

### 6. Cleanup

```bash
wt-worker cleanup <branch>
```

1. **refresher プロセスに SIGTERM** (race 防止のため最初)
2. `sbx rm <sandbox名>` でサンドボックスを削除
3. `git worktree remove --force` + `rmdir` で `.sbx/` 下のディレクトリを掃除
4. `git branch -D <branch>` でブランチも削除
5. `wezterm cli kill-pane` で pane を削除し pane-id / repo / pid ファイルを削除

### 7. その他

| コマンド | 用途 |
|---|---|
| `wt-worker list` | `sbx ls` で起動中の sandbox を表示 |

## WezTerm 連携の詳細

### pane 作成

```bash
PANE_ID=$(wezterm cli split-pane \
  --bottom --percent 30 \
  --pane-id "$WEZTERM_PANE" \
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

`~/.config/wt-worker/config.toml` に列挙した plugin を、`wt-worker spawn` 時に
sbx の追加 workspace として read-only マウントし `claude --plugin-dir` で渡します。

```toml
[[marketplaces]]
name    = "td72"
plugins = ["wt-worker"]

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

sbx プロキシが API 認証を透過的に処理するため、worker 内に token は露出しません。

### Anthropic

```bash
sbx secret set -g anthropic   # ホストで 1 回だけ (global)
```

### GitHub (シンプル)

```bash
sbx secret set -g github   # fine-grained PAT を入力 (全 sandbox 共通)
```

### GitHub (推奨: per-repo 最小権限)

[`agent-gh-repo-token`](https://github.com/td72/agent-gh-repo-token) をホストに入れて
おくと、`wt-worker spawn` は:

1. `git remote get-url origin` から `<host>/<owner>/<repo>` を導出
2. `agent-gh-repo-token --repo <それ>` を呼び出し
3. 成功すれば stdout の token を `sbx secret set <sandbox名> github` に流す
4. **background refresher を `nohup` で起動** (50 分ごとに 2〜3 を繰り返す)
5. 失敗・未インストールはグローバル `-g github` の secret に fallback

token は GitHub App 仕様で 1 時間で失効するため、`spawn` と同時に背景プロセスが
立ち上がり worker が稼働中はずっと自動で更新されます。`wt-worker cleanup` 時に
SIGTERM で停止。手動で再 mint したいときは `wt-worker refresh <branch>`。

`agent-gh-repo-token` 自体は GitHub App + 1Password に基づき
「**現在の repo の・指定 permission だけ・1時間で失効する**」installation token を
mint します。詳細 (App 作成手順・`repos.toml` の書き方・解決規則) は同ツールの
README を参照。

インストール:

```bash
curl -fsSL https://raw.githubusercontent.com/td72/agent-gh-repo-token/main/scripts/install.sh | sh
# または: go install github.com/td72/agent-gh-repo-token@latest
```

## オープン課題

1. **pane が増えすぎた場合**: 一定数を超えたら自動で tab に切り替える等の拡張は将来検討
2. **依存関係のある worker**: worker B が worker A の成果物に依存するケースは MVP のスコープ外 (人間が `git merge` してから B を spawn)
3. **完了の自動検知**: `✻ Worked for` パターン or git commit 監視で `wt-worker wait <branch>` を実装する余地あり

## 関連

- `mise.toml`: ツールチェイン管理
- Docker Sandboxes: <https://docs.docker.com/ai/gordon/docker-sandboxes/>
- WezTerm CLI: <https://wezfurlong.org/wezterm/cli/general.html>
- GitHub Apps: <https://docs.github.com/en/apps/creating-github-apps>
- 1Password CLI: <https://developer.1password.com/docs/cli/>

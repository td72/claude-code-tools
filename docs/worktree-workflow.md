# Worktree × Sandbox 並列開発ワークフロー

## ゴール

- 1 つの WezTerm ウィンドウ内で、**司令塔 claude** と **複数の worker claude** が共存する開発スタイルを定義する
- 各 worker は独立した git worktree と Docker サンドボックス上で動作し、ホスト環境や他 worker と隔離される
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
|  $ ccwt spawn feature-x "<initial task>"                |
+--------------------------------------------------------+
|  worker A (docker exec → claude REPL, branch=feature-x)|
|  > implement ...                                       |
+--------------------------------------------------------+
|  worker B (docker exec → claude REPL, branch=feature-y)|
|  > implement ...                                       |
+--------------------------------------------------------+
```

### 司令塔 (Commander)

- ホスト OS 上の claude code セッション
- `ccwt` CLI を叩いて worker のライフサイクルを管理
- worker pane を `wezterm cli get-text` で覗き、`wezterm cli send-text` で追加指示を投入
- worker のブランチをレビュー・マージ

### Worker

- Docker サンドボックス内で動く claude REPL（対話モード）
- worktree ディレクトリだけが `/workspace` にマウントされ、他リポジトリやホスト全体には触れない
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

~/.local/state/ccwt/<repo>/             # 司令塔のローカル状態 (XDG 準拠)
  ├─ commander                         # 司令塔自身の pane-id
  └─ panes/<branch>                    # branch ごとの WezTerm pane-id
```

- 本体は `~/src/...`
- worktree は `~/worktrees/...` (gwq 既定)
- 司令塔の状態は `~/.local/state/ccwt/<repo>/` （XDG_STATE_HOME 準拠）。リポジトリ内には**置かない**ので git status を汚さない

## 前提ツール

| ツール | 用途 | 入手 |
|---|---|---|
| `gwq` | worktree の add / list / get / remove | `mise.toml` の `[tools]` に追加 |
| `wezterm` (cli) | pane の split / send-text / get-text | ホストに既存 |
| `docker` | サンドボックス起動 | ホストに既存 |
| `tedsum/claude-code-mise` | サンドボックスイメージ | 本リポの `Dockerfile` |

## ライフサイクル

### 0. Init

```bash
ccwt init
```

- 現在の WezTerm pane-id (`wezterm cli list --format json` から特定) を `~/.local/state/ccwt/<repo>/commander` に保存
- 以降の `ccwt spawn` はこの pane を基点にして下に pane を積む

### 1. Spawn

```bash
ccwt spawn <branch> ["<initial-task>"]
```

実行手順:

1. `gwq add <branch>` で worktree を作成（パスは `~/worktrees/github.com/<owner>/<repo>/<branch>/`）
2. `wezterm cli split-pane --bottom --percent 30 --pane-id $(cat ~/.local/state/ccwt/<repo>/commander) --cwd $(gwq get <branch>)` で **常に司令塔の下** に pane を追加
3. 返却された `pane-id` を `~/.local/state/ccwt/<repo>/panes/<branch>` に保存
4. `docker run -d --name ccwt-<branch> -v $(gwq get <branch>):/workspace tedsum/claude-code-mise sleep infinity` でサンドボックスを起動
5. pane 内で `docker exec -it ccwt-<branch> claude` を叩いて REPL に入る（`send-text` で投入）
6. `<initial-task>` が指定されていれば、続けて pane に送信

### 2. 追加指示

```bash
ccwt tell <branch> "<message>"
```

- `~/.local/state/ccwt/<repo>/panes/<branch>` から pane-id を読み出し
- `wezterm cli send-text --pane-id <id> "<message>"` で投入
- claude REPL は Enter で送信されるため、末尾に CR を別送する

### 3. 完了検知

対話モードでは「タスクが終わった」を機械的に判定する確実な方法がない。本ワークフローではシンプルに以下のみで運用する:

- **pane 観察**: 司令塔が必要に応じて `wezterm cli get-text --pane-id <id> --start-line -200` で末尾を読む
- **人間判断**: 最終確認は人間が pane を見て行う

git コミットメッセージに完了マーカーを埋め込むような運用は**しない**（コミット履歴を汚さない）。

### 4. Cleanup

```bash
ccwt cleanup <branch>
```

1. `docker kill ccwt-<branch> && docker rm ccwt-<branch>`
2. `wezterm cli kill-pane --pane-id <id>`
3. `~/.local/state/ccwt/<repo>/panes/<branch>` を削除
4. `gwq remove <branch>` （未コミット変更が残っていれば人間に確認）

### 5. その他コマンド

| コマンド | 用途 |
|---|---|
| `ccwt list` | 起動中の worker 一覧（`gwq list` と `docker ps` を JOIN） |
| `ccwt attach <branch>` | 既存 pane にフォーカス移動 (`wezterm cli activate-pane --pane-id <id>`) |
| `ccwt kill <branch>` | サンドボックスのみ落とす（worktree は残す） |
| `ccwt logs <branch>` | pane の末尾 N 行を司令塔の標準出力に流す |

## WezTerm 連携の詳細

### pane 作成

```bash
PANE_ID=$(wezterm cli split-pane \
  --bottom --percent 30 \
  --pane-id "$(cat ~/.local/state/ccwt/<repo>/commander)" \
  --cwd "$WORKTREE_PATH")
```

- `--bottom`: 司令塔の下に積む
- `--percent 30`: 司令塔: 直前領域 = 7 : 3 で分割
- 常に司令塔の pane を基点にするため、worker は司令塔の真下に積み上がる

### テキスト投入

```bash
wezterm cli send-text --pane-id "$PANE_ID" "$MESSAGE"
printf '\r' | wezterm cli send-text --pane-id "$PANE_ID" --no-paste
```

### 出力取得

```bash
wezterm cli get-text --pane-id "$PANE_ID" --start-line -200
```

## Docker サンドボックスの要件

現状の `tedsum/claude-code-mise` に対する確認・追加事項:

- [ ] `claude` CLI が PATH に通っている
- [ ] `git` が同梱されている
- [ ] worktree マウント時に owner mismatch で git が拒否しないよう、`git config --global safe.directory '*'` を設定
- [ ] 作業ディレクトリを `/workspace` にする (`WORKDIR /workspace`)
- [ ] ANTHROPIC_API_KEY をホストから安全に渡す経路を決める（`docker run --env-file` か OAuth）

## 実装方針

- MVP は **Bash スクリプト** で実装する (`bin/ccwt` = claude code worktree)
- サブコマンドは case 文でディスパッチ
- 依存: bash 4+, gwq, wezterm, docker, git
- 運用が固まったら Go への書き換えを検討（gwq と同じ路線）

## オープン課題

1. **司令塔の権限**: 司令塔も claude code セッション内で動くため、`ccwt` から `wezterm cli`・`docker`・`gwq` を叩く権限を `.claude/settings.json` の permission に追加する必要がある
2. **認証情報の引き渡し**: ホストの `~/.claude/` をマウントするか、API キーを env で渡すか、OAuth フローをサンドボックス内で完結させるか
3. **依存関係のある worker**: worker B が worker A の成果物に依存するケースは MVP のスコープ外（人間が `git merge` してから B を spawn）
4. **pane が増えすぎた場合**: 一定数を超えたら自動で tab に切り替える等の拡張は将来検討

## 関連

- `mise.toml`: ツールチェイン管理
- `Dockerfile`: サンドボックスイメージ定義
- gwq: <https://github.com/d-kuro/gwq>
- WezTerm CLI: <https://wezfurlong.org/wezterm/cli/general.html>

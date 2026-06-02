# wt-worker トラブルシューティング

よくある問題と対処法を FAQ 形式でまとめます。
設計の詳細は [`worktree-workflow.md`](./worktree-workflow.md) を参照。

---

## Q1. worker の REPL が "Not logged in" と表示される

**症状**: `wt-worker spawn` 後、worker pane に Claude が起動したが Anthropic への認証に失敗し
「Not logged in」や「Authentication failed」が表示される。

**原因**: sbx の `--kit` オプションを使うと Anthropic credential wiring がリセットされます。
`wt-worker spawn` はこれを避けるため `--kit` を一切使わず stock の claude-code イメージで
起動しますが、既存の壊れた sandbox が残っていると同じ名前でコンフリクトすることがあります。

**対処**:

```bash
# 1. 壊れた worker を削除
wt-worker cleanup <branch>

# 2. 再 spawn
wt-worker spawn <branch> "<initial-task>"
```

> **注意**: `spawn` は既存の live worker を上書き・再利用しません。
> 「REPL が変な状態になった」「別タスクで一から始めたい」といった場合も
> 必ず cleanup → spawn の順で行ってください。
> pane を放置しても worker は動き続け、sandbox リソースを消費します。

---

## Q2. e2e テストがサンドボックス内で動かない

**症状**: worker 内で `pnpm exec playwright test` や `vp build` などを実行すると、
ネイティブバイナリのロードエラーや「executable not found」が出て失敗する。

**原因**: `wt-worker spawn` は ホスト worktree を **direct mount** します。
そのため worker から見える `node_modules` には **ホスト OS (macOS) 向けのネイティブバイナリ**
が含まれています。vite-plus / rolldown / oxc / esbuild / Playwright のブラウザバイナリは
Linux コンテナ上ではロードできず、`vp build`・e2e の webServer・ブラウザがすべて落ちます。

**対処**: `wt-worker verify` を使います。これは**司令塔側**で CI と同等のクリーンな
Linux コンテナを立ち上げ、`git archive` で `node_modules` を含まないコミット済みツリーを
export してからテストを実行します。

```bash
# 先にコミットしてから呼ぶ (verify は committed HEAD を対象とする)
git commit -m "..."

# クリーンコンテナで e2e を回す
wt-worker verify <branch>
# → 0 = PASS, 非0 = FAIL
```

事前に `~/.config/wt-worker/config.toml` へ `[verify]` セクションを追加しておく必要があります
(未設定の場合は `verify` がヒントを出して終了します)。
設定例は [`examples/config.toml`](../examples/config.toml) を参照。

> **worker 内で `pnpm install` すれば直せますか?**
>
> ホスト `node_modules` を上書きするためホスト側の開発環境が壊れます。推奨しません。
> 現時点では `wt-worker verify` で代替してください。
> worker が自己完結できる「`spawn --heavy` モード」は将来の検討事項です
> ([worktree-workflow.md §オープン課題](./worktree-workflow.md#オープン課題) 参照)。

---

## Q3. GitHub token が 1 時間で失効して push が通らなくなった

**症状**: worker が稼働中に `git push` が `403` や `could not read Username` で失敗しはじめた。

**原因**: `agent-gh-repo-token` が発行する GitHub App installation token は **1 時間で失効**します。

**通常は自動更新されます**: `wt-worker spawn` は同時に background refresher を `nohup` で
起動し、**50 分ごと**に token を再 mint して sandbox secret を上書きします。
ターミナルを閉じても refresher は生き続けます。

**手動対処が必要なケース** (refresher が死んでいる場合):

```bash
# ホスト再起動後など、refresher が落ちているときは手動で再 mint
wt-worker refresh <branch>

# refresher のログを確認したいとき
cat ~/.local/state/wt-worker/<repo>/refreshers/<branch-sanitized>.log
```

**refresher が動いているか確認**:

```bash
pid_file=~/.local/state/wt-worker/<repo>/refreshers/<branch-sanitized>.pid
kill -0 "$(cat "$pid_file")" 2>/dev/null && echo "alive" || echo "dead"
```

> `agent-gh-repo-token` が PATH にない場合、refresh は no-op です。
> その場合はグローバル PAT (`sbx secret set -g github`) を使ってください。

---

## Q4. `git push` が SSH で失敗する

**症状**: worker 内で `git push origin` が
`git@github.com: Permission denied (publickey)` や
`ssh: connect to host github.com port 22: Connection refused` で失敗する。

**原因**: worker (sbx コンテナ) は SSH キーを持ちません。
sbx プロキシは **HTTPS トラフィックのみ**を透過的に認証するため、
SSH プロトコルの git 操作はそのまま通りません。

**対処**: `wt-worker spawn` は `git config --global url."https://github.com/".insteadOf` を
仕込み、`git@github.com:...` 形式の SSH URL を自動的に HTTPS に書き換えます。
そのため **`git push origin` をそのまま実行すれば** sbx プロキシ経由で通ります。

```bash
# worker 内で — SSH キー不要
git push origin <branch>
```

それでも失敗する場合は GitHub secret が設定されているか確認:

```bash
# 司令塔側で確認
sbx secret ls wt-worker-<branch-sanitized>

# secret がなければ手動で注入 (グローバル PAT)
sbx secret set wt-worker-<branch-sanitized> github

# または agent-gh-repo-token が使える環境なら
wt-worker refresh <branch>
```

> **gh CLI で PR を作りたい場合**: `wt-worker spawn` は
> `~/.config/gh/hosts.yml` に sentinel token を書き込み、gh が HTTPS 経由で
> 動けるよう事前設定します。`gh pr create` はそのまま worker 内で実行できます。

# FAQ

## Q1. worker はどこで動くの?

**コンテナ内のプライベートクローン**で動きます。

`wt-worker spawn` は `sbx --clone` を使い、ホスト repo をコンテナ内に丸ごとクローンします。ホスト repo はコンテナに read-only でマウントされるだけで、ホスト側に worktree は作られません。

```
ホスト repo (RO マウント)
      │
      └──clone──▶ コンテナ内 /home/agent/workspace  ← worker の作業空間
```

worker はこのクローン上で自由に commit・branch・push できます。ホスト環境や他 worker と完全に隔離されているため、依存関係のインストールや実験的な変更も安全に行えます。

> 詳細: [worktree-workflow.md § ディレクトリレイアウト](./worktree-workflow.md#ディレクトリレイアウト)

---

## Q2. PR はどうやって作るの?

**worker が直接 `git push origin <branch>` → `gh pr create` します。**

`wt-worker spawn` が sandbox を作る際に、以下を自動で仕込みます:

1. **ssh → https 書き換え** (`git config pushInsteadOf`) — `git@github.com:...` な origin を https に変換
2. **GitHub token の注入** — `sbx secret set` で sandbox 固有の GitHub token を設定し、sbx プロキシが透過的に認証

これにより worker は追加設定なしに GitHub へ push でき、そのまま `gh pr create` も実行できます。token はコンテナ内に露出しません。

```bash
# worker が実行するだけ — 追加設定不要
git push origin feature/foo
gh pr create --title "..." --body "..."
```

> 詳細: [worktree-workflow.md § 認証](./worktree-workflow.md#認証) / [README § worker の作業空間](../README.md#worker-の作業空間-in-container-clone)

---

## Q3. e2e 検証はどうするの?

**司令塔側で `wt-worker verify <branch>` を実行します。**

```bash
wt-worker verify feature/foo   # ← 司令塔が実行
```

`verify` は worker とは別の**クリーンな Linux コンテナ**を立て、CI と同じ条件でブランチのテストを回します。

```
司令塔
  └─ wt-worker verify feature/foo
        │
        ├─ git archive でブランチツリーを export (node_modules を含まない)
        ├─ クリーンコンテナで config.toml の [verify].command を実行
        └─ exit code = 0 (pass) / 非0 (fail)
```

**worker 内ではなく司令塔側から実行する理由:**

- worker 内で e2e を回すにはブラウザバイナリや backend の別途準備が必要で確実性に欠ける
- `verify` は CI 一致・push 前に赤緑が確定するという価値がある

`config.toml` の `[verify].command` が未設定の場合はヒントを出して終了します。`verify` はコミット済み HEAD を対象とするため、**先にコミットしてから**呼んでください。

> 詳細: [worktree-workflow.md § Verify](./worktree-workflow.md#7-verify-ci-パリティのテスト実行)

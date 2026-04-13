# arming

Git helper：自动判定模式（clone/export/update），串行执行，TTY 友好的状态输出与摘要。

## Install

```sh
chmod +x arming.sh
```

## Usage

- Export remotes: `./arming.sh ./my_repos > git.list`
- Clone from list: `./arming.sh ./new_home < git.list`
- Update repos: `./arming.sh ./my_repos`

模式自动判断：stdin 有管道 -> clone；stdout 被重定向 -> export；否则 update。

## Output format

导出行格式：`https://github.com/username/reponame.git rereponame_username`
如果列表省略名称，clone/update 会按该规则推导目录名。

## Behavior

- Clone：串行执行，输出 `[n/total] [OK|FAIL|SKIP] name`，已存在仓库自动跳过并计入摘要。
- Update：串行 `git pull --ff-only`，输出 `[n/total] [OK|FAIL] name`，结束后摘要 Updated/Failed。
- Export：逐仓库输出 remote+推导名。
- 彩色/进度提示仅在 TTY 时启用，避免干扰重定向内容。


## Notes

- 依赖：`git`；启动时检查
- Clone 默认 `--depth 1`
- `SUMMARY_LIMIT` 控制摘要列表最大展示条数（默认 20）

# Utils 复用工具

> 频繁使用的辅助工具(做图 / 机器状态查询 / 运行状态查询 / 日志分析等)。
> 原则: **复用而非重写** — 需要工具时先查本表; 新工具写完后登记。
> 本索引由 agent 直接维护; 脚本本体在 utils/ 下。

<!-- 登记示例: | plot-loss | 画训练曲线 | 迭代关闭后出图 | python utils/plot-loss.py data/loss.log | [utils/plot-loss.py](utils/plot-loss.py) | -->
| 工具 | 用途 | 何时使用 | 用法 | 链接 |
| --- | --- | --- | --- | --- |

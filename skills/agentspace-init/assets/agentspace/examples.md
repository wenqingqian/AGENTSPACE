# Examples 实验配置

> 本文件是 examples/ 的入口, 存放可复用的实验配置。
> 配置文件(如 YAML/JSON)供 tests/ 中的测试脚本引用; 实验参数与运行脚本分离。
> tests/ 放入口脚本(如何跑), examples/ 放配置(用什么参数跑)。
> exp_spec 子树除外: 所有经 agentspace-exp 登记的实验, 其配置必须写入 `examples/exp_spec/exp_NNNN/`(由 new-exp.sh 预创建); 该子树由 exp/index.md 的配置列索引, 不在本表登记。

## 配置清单

<!-- 登记示例: | resnet50-train.yaml | 训练超参(bs=256, lr=0.1) | train.py | [examples/resnet50-train.yaml](examples/resnet50-train.yaml) | -->
| 配置 | 说明 | 关联测试 | 链接 |
| --- | --- | --- | --- |

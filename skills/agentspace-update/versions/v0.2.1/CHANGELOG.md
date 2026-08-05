# AGENTSPACE v0.2.1

Upgrade from v0.2.0. Date: 2026-07-31

## Summary

- New built-in module: data.md + data/ for shared data (training sets, model weights, symlinks)
- New built-in module: examples.md + examples/ for reusable experiment configs (pairs with tests/)

## Changes

### [Addition] data module (data.md + data/)

**What**: new built-in module for project shared data — training sets, model weights, preprocessed data, or symlinks to external locations.

**Why**: multiple experiments often need the same data; centralizing avoids duplication and makes data provenance clear.

**Migration (both modes — non-destructive addition)**:

1. Create directory: `mkdir -p AGENTSPACE/data`

2. Create entry file: copy `skills/agentspace-init/assets/agentspace/data.md` to `AGENTSPACE/data.md`

3. Update `.gitignore`: add these lines after the `iterations/*/data/` line:
   ```
   # ---- 公用数据: 全部不入 git (训练集/模型权重/软连接等) ----
   data/
   ```

4. Update `AGENTSPACE/AGENTS.md` — insert data module in two places:

   a. In the **结构** code block, add this line **before** `utils.md + utils/`:
   ```
   ├── data.md + data/    ← 公用数据(训练集/模型权重/软连接; 全部 gitignore)
   ```

   b. In the **模块: what / when / how** section, add this subsection **before** `### utils`:
   ```markdown
   ### data —— 公用数据 (data.md + data/)
   - **what**: 项目公用数据(训练集、模型权重、预处理数据等); 也可以是对其他位置的软连接
   - **when/how**: 多个实验需要同一份数据时放入 data/ 并在 data.md 登记; 大文件/权重默认 gitignore, 小型共享文件可取消注释
   ```

5. Update the `### register` description: change `(例如 examples.md + examples/ 存放固定测试配置)` to `(按项目需要扩展, 如 visualization.md + visualization/)`

### [Addition] examples module (examples.md + examples/)

**What**: new built-in module for reusable experiment configurations (YAML/JSON etc.); pairs with tests/ — tests/ holds entry-point scripts (how to run), examples/ holds configs (what parameters).

**Why**: separating experiment configs from run scripts improves reusability and clarity.

**Migration (both modes — non-destructive addition)**:

1. Create directory: `mkdir -p AGENTSPACE/examples`

2. Create entry file: copy `skills/agentspace-init/assets/agentspace/examples.md` to `AGENTSPACE/examples.md`

3. Update `AGENTSPACE/AGENTS.md` — insert examples module in two places:

   a. In the **结构** code block, add this line **before** `utils.md + utils/` (after the data line):
   ```
   ├── examples.md + examples/ ← 可复用实验配置(YAML/JSON); 与 tests/ 配合(脚本在 tests/, 配置在 examples/)
   ```

   b. In the **模块: what / when / how** section, add this subsection **before** `### utils` (after the data subsection):
   ```markdown
   ### examples —— 实验配置 (examples.md + examples/)
   - **what**: 可复用的实验配置文件(YAML/JSON 等); 与 tests/ 配合: tests/ 放入口脚本(如何跑), examples/ 放配置(用什么参数跑)
   - **when/how**: 有可复用的实验参数/配置时放入 examples/ 并在 examples.md 登记; 测试脚本通过路径引用 examples/ 下的配置
   ```

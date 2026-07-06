# GPU 集群运行说明（Conda）

> 账号：`zhangzhuoyu` · 节点：`202.120.45.56:22236`（GPU-A800）  
> 本集群 **跑不了 `.sif`**，用下面 conda 流程即可（已在 test_001 跑通）。

---

## 1. 路径（按实际 home 改）

```bash
export DEEPRARE_ROOT=/export/home/zhangzhuoyu/DeepRare
export QWEN_MODEL=/export/home/zhangzhuoyu/.cache/huggingface/hub/models--Qwen--Qwen3-14B/snapshots/40c069824f4251a91eefaf281ebe4c544efd3e18
export EMBED_APIKEY=sk-...          # 向账号主人要 xiaoai key（见下方说明）
export CUDA_VISIBLE_DEVICES=6       # Qwen 用 GPU 5/6/7（约 28G 显存）
export INFER_GPU=0                  # DeepRare 用 GPU 0
```

可选：复制 `containers/env.example` 为 `containers/env.local`，填好 key 后 `source containers/env.local`。

---

## 为什么要 xiaoai key？会联网吗？

| 环节 | 是否联网 | 说明 |
|------|----------|------|
| **主 LLM（诊断推理）** | 否 | 本地 Qwen3-14B，`127.0.0.1:8000` |
| **Embedding** | **是** | 调用 xiaoai 的 `text-embedding-3-small`，在 `database/RDS_embeddings.csv` 里做**相似病例检索** |
| **DuckDuckGo 搜索** | 尝试联网 | 集群上常失败，一般不影响主流程 |
| **Exomiser** | 否 | 本地 jar + 本地 data |

所以：**不是用 xiaoai 跑大模型**，只是**相似病例向量化**这一步要走 xiaoai API。没有 key 会在 embedding 阶段报错。

---

## 2. 启动 Qwen3-14B（tmux 1）

> **注意：** `tmux new` 会开**新 shell**，不会继承外面的 `conda activate`。命令都要在 tmux **里面**执行。  
> 若已有 session：`tmux attach -t qwen3-serve`（不要重复 `tmux new`，会报 duplicate）。

```bash
# 在 tmux 外先设好变量（可选）
export QWEN_MODEL=/export/home/zhangzhuoyu/.cache/huggingface/hub/models--Qwen--Qwen3-14B/snapshots/40c069824f4251a91eefaf281ebe4c544efd3e18
export CUDA_VISIBLE_DEVICES=6

tmux new -s qwen3-serve    # 已有则: tmux attach -t qwen3-serve
```

**进入 tmux 后整段复制：**

```bash
conda activate qwen3_infer
cd ~/DeepRare

export QWEN_MODEL=/export/home/zhangzhuoyu/.cache/huggingface/hub/models--Qwen--Qwen3-14B/snapshots/40c069824f4251a91eefaf281ebe4c544efd3e18
export CUDA_VISIBLE_DEVICES=6

which python    # 应含 .../envs/qwen3_infer/bin/python
python -c "import torch; print('qwen OK', torch.__version__)"

python scripts/qwen_openai_server.py \
  --model "$QWEN_MODEL" \
  --port 8000 \
  --host 0.0.0.0 \
  --fp16
# 等到 Model ready → Ctrl+b d
```

若报 `address already in use`：8000 已被旧 Qwen 占用，`curl http://127.0.0.1:8000/v1/models` 有输出则**不用重启**。

检查：

```bash
curl -s http://127.0.0.1:8000/v1/models | python3 -m json.tool
```

---

## 3. 跑 DeepRare 基因模式（tmux 2，另开 SSH）

> **必须在 tmux 里 `conda activate deeprare`**，否则会用错 Python，报 `No module named 'pandas'`。  
> 提示符应是 `(deeprare) [zhangzhuoyu@GPU-A800 DeepRare]$`，不能只有 `[zhangzhuoyu@...]`。

```bash
tmux new -s deeprare-infer    # 已有则: tmux attach -t deeprare-infer
```

**进入 tmux 后整段复制：**

```bash
conda activate deeprare
cd ~/DeepRare

export INFER_GPU=0
export EMBED_APIKEY=sk-...    # xiaoai，必填
export QWEN_MODEL=/export/home/zhangzhuoyu/.cache/huggingface/hub/models--Qwen--Qwen3-14B/snapshots/40c069824f4251a91eefaf281ebe4c544efd3e18

# 跑前自检（防止环境不对）
which python
python -c "import pandas, torch; print('deeprare OK', pandas.__version__, torch.__version__)"
curl -s http://127.0.0.1:8000/v1/models | head -c 200 && echo

bash inference_gene_qwen.sh
# 成功会看到: Patient 0 diagnosis completed.
# Ctrl+b d
```

`which python` 应类似：

```text
/export/home/zhangzhuoyu/miniconda3/envs/deeprare/bin/python
```

若 `import pandas` 仍失败（已 activate deeprare 时）：

```bash
conda install -c conda-forge pandas -y
```

结果：`result_gene/case/Qwen_Qwen3-14B/patient_*.json`

---

## 4. 加病例

编辑 `dataset/cases.csv`，VCF 放 `data/vcf/`：

| 列 | 说明 |
|----|------|
| `hpo` | 表型，`\|` 分隔，如 `Seizure\|Hearing impairment` |
| `disease` | 可填 `[]` |
| `vcf_path` | 如 `./data/vcf/xxx.vcf` |

---

## 5. 注意

- **tmux 里记得 conda activate**（见第 2、3 节），是最常见的报错原因。
- VCF/结果为**敏感数据**，勿上传 git，注意目录权限。
- 跑前 `nvidia-smi` 看 GPU 是否空闲。
- Qwen 挂了会连不上 `:8000`，先 `tmux attach -t qwen3-serve` 看日志。
- 缺 `database/`、`exomiser-cli-14.0.0/` 会报错，项目里应已有。

---

## 6. `.sif` 镜像（本集群不用）

已备份在 Sylabs：`library://wmx238/deeprare/...`，其他集群可用。本机 CentOS 7 无法 `singularity run`。

---

## 7. 常用命令

```bash
tmux ls
tmux attach -t qwen3-serve
tmux attach -t deeprare-infer
```

参考输出对比：`docs/test_001_comparison.md`

---

## 8. 结果汇总统计

推理完成后，汇总 `result_gene/` 下所有 `patient_*.json`：

```bash
conda activate deeprare
cd ~/DeepRare

python scripts/summarize_gene_results.py
```

结果目录结构为 `result_gene/<数据集>/<模型>/patient_*.json`。同一 VCF（如 `test_001`）若改了 `dataset/cases.csv` 里的表型再跑，文件名仍可能是 `patient_0.json`，脚本会用 **case_key**（`样本 | 表型`）区分，并在末尾打印 Overview。

导出 CSV 表格（便于对照查看）：

```bash
python scripts/summarize_gene_results.py \
  --result-dir result_gene \
  --dataset case \
  --csv result_gene/summary_case.csv
```

汇总全部数据集（不只 `case`）时，将 `--dataset` 设为空字符串：

```bash
python scripts/summarize_gene_results.py --dataset '' --csv result_gene/summary_all.csv
```

只看某一个模型输出文件夹（该目录下直接有 `patient_*.json`）：

```bash
# 方式 1：--run-dir 指定子目录
python scripts/summarize_gene_results.py \
  --run-dir result_gene/case/Qwen_Qwen3-14B

# 方式 2：--result-dir 直接指向该文件夹（效果相同）
python scripts/summarize_gene_results.py \
  --result-dir result_gene/case/Qwen_Qwen3-14B

# 导出该文件夹的 CSV
python scripts/summarize_gene_results.py \
  --run-dir result_gene/case/Qwen_Qwen3-14B \
  --csv result_gene/summary_qwen_case.csv
```

输出包含：数据集、case_key、模型、病例编号、表型、VCF、Exomiser Top 基因、AI Top5 诊断、耗时、JSON 路径。


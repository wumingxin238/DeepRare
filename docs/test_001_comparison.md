# test_001 对比分析：gpt-4o vs 本地 Qwen3-14B

> DeepRare 基因模式（HPO + VCF）单病例对比报告  
> 病例 ID：`test_001`  
> 生成日期：2026-06-16

---

## 1. 病例信息

| 项目 | 内容 |
|------|------|
| 病例 ID | test_001 |
| 表型 (HPO) | Seizure (HP:0001250)、Hearing impairment (HP:0000365)、Leukocytosis (HP:0001974) |
| VCF | `./data/vcf/test_001.vcf` |
| 金标准诊断 | 无（`golden_diagnosis` 为空，无法自动评估准确率） |

---

## 2. 运行概况

| 项目 | gpt-4o | Qwen3-14B（本地） |
|------|--------|-------------------|
| 推理脚本 | `inference_gene.sh` | `inference_gene_qwen.sh` |
| LLM | xiaoai `gpt-4o` | 本地 OpenAI 兼容 API `Qwen/Qwen3-14B`（`:8000`） |
| Embedding | xiaoai `text-embedding-3-small` | 同左 |
| 耗时 | **209 s** | **214 s** |
| 结果路径 | `result_gene/case/gpt-4o/patient_0.json` | `result_gene/case/Qwen_Qwen3-14B/patient_0.json` |
| Exomiser 输出 | `result_gene/exomiser_results/diagnosis_result_test_001.json` | 同左（同一 VCF，结果一致） |

**说明：** 两次耗时接近，主要因为 Exomiser 与外部检索步骤相同；本地 Qwen 在本例中未显著拖慢整体流程。

### 共同中间结果

- **PubCaseFinder / Phenobrain**：两次输入与输出一致
- **DuckDuckGo 网页搜索**：两次均失败
- **Exomiser**：基因排名完全一致（见下节）

---

## 3. Exomiser 基因层（完全一致）

| 排名 | 基因 | Exomiser 分数 | 关联疾病 | ClinVar |
|------|------|---------------|----------|---------|
| 1 | **KMT2C** | 0.942 | Kleefstra syndrome 2 | BENIGN_OR_LIKELY_BENIGN |
| 2 | **ATP7A** | 0.794 | Menkes disease / Occipital horn syndrome | CONFLICTING |
| 3 | **SLC12A6** | 0.769 | Agenesis of corpus callosum with peripheral neuropathy (ACC-PN) / CMT2II | UNCERTAIN |
| 4 | HPR | 0.763 | — | UNCERTAIN |
| 5 | DOCK5 | 0.757 | — | UNCERTAIN |

**结论：** 基因证据层由 Exomiser 决定，与 LLM 选择无关；两次运行结果相同。

---

## 4. 表型路径（仅 HPO，融合基因前）

### 4.1 零样本 Top-5

| 排名 | gpt-4o | Qwen3-14B |
|------|--------|-----------|
| #1 | Alpers-Huttenlocher syndrome | Cockayne syndrome |
| #2 | Cockayne syndrome | Rett syndrome |
| #3 | Muckle-Wells syndrome | Alström syndrome |
| #4 | Chediak-Higashi syndrome | Neuronal ceroid lipofuscinoses |
| #5 | Refsum disease | Mucolipidosis IV |

两者均偏向「罕见神经 + 听力 + 癫痫」类疾病，但具体排序差异较大。

### 4.2 多轮表型初步诊断（preliminary）

| 排名 | gpt-4o | Qwen3-14B |
|------|--------|-----------|
| #1 | **Cerebral venous thrombosis (CVT)** | **Alpha-mannosidosis** |
| #2 | Mitochondrial encephalomyopathy | MOG-IgG encephalitis |
| #3 | Neurosarcoidosis | CVT |
| #4 | Autoimmune encephalitis | Hereditary spastic paraplegia (HSP) |
| #5 | Intracranial vasculitis | MELAS |

**差异原因简述：**

- **gpt-4o**：相似病例检索更突出 **CVT** 一例，表型路径被其主导。
- **Qwen3-14B**：检索到 **3 个**相似病例（Alpha-mannosidosis、MOG-IgG encephalitis、CVT），表型路径被 **Alpha-mannosidosis** 带偏。

---

## 5. 最终诊断（Exomiser + 表型融合）

### 5.1 共同 Top-3（高度一致）

| 排名 | gpt-4o | Qwen3-14B |
|------|--------|-----------|
| **#1** | **Kleefstra syndrome 2** (KMT2C) | **Kleefstra syndrome 2** (KMT2C) |
| **#2** | **Menkes disease** (ATP7A) | **Occipital horn syndrome / Menkes** (ATP7A) |
| **#3** | **ACC-PN** (SLC12A6) | **ACC-PN** (SLC12A6) |

**核心结论：** 更换为本地 Qwen3-14B 后，**基因驱动的最终 Top-3 与 gpt-4o 一致**，说明 DeepRare 基因模式对主结论较稳健。

### 5.2 #4–#5 的差异

| 排名 | gpt-4o | Qwen3-14B |
|------|--------|-----------|
| #4 | Occipital horn syndrome (ATP7A) | **Alpha-mannosidosis**（表型候选，Exomiser 未直接支持） |
| #5 | ACC-PN / CMT2II（SLC12A6，与 #3 重复展开） | Hereditary spastic paraplegia（表型弱支持） |

- **gpt-4o**：#4–#5 更紧扣 Exomiser 已提示的基因（ATP7A、SLC12A6）。
- **Qwen3-14B**：将表型阶段的 Alpha-mannosidosis 保留进最终 #4，并注明 Exomiser 未直接支持——整合更「折中」，但也引入表型侧幻觉风险。

---

## 6. 质量与可信度评估

### Qwen3-14B 的优点

- 最终基因 Top-3 与 gpt-4o 一致。
- 对 KMT2C 的 ClinVar「良性/可能良性」有保留态度。
- 会区分「基因支持」与「仅表型 plausible」（如 Alpha-mannosidosis）。

### Qwen3-14B 的问题

- 表型阶段引用了 **疑似编造的 PMC 链接**（如 PMC7155456/57/58），应视为幻觉。
- 初步诊断中出现 **MRI 表现** 等 test_001 未提供的临床信息（可能来自相似病例，但未明确隔离来源）。
- #5 HSP 与当前表型组合匹配较弱。

### gpt-4o 的问题

- Exomiser 步骤 JSON 中 `model_used` 误标为 `deepseek-v3-241226`（`exomizer_inference.py` 硬编码 bug，不影响实际 API 调用）。
- 表型阶段过度依赖单一 CVT 相似病例。
- 知识库检索大量返回 `Not found`（环境/网络问题，两次相同）。

---

## 7. 临床解读（无金标准下的建议）

在缺少 golden diagnosis 的情况下，两次结果共同指向以下验证优先级：

1. **KMT2C / Kleefstra syndrome 2** — Exomiser 分数最高，但 ClinVar 偏良性，需 segregation 与功能验证。
2. **ATP7A（Menkes / occipital horn syndrome）** — 与癫痫、听力障碍较吻合，ClinVar 为 conflicting。
3. **SLC12A6（ACC-PN）** — splice 变异 VUS，建议 RNA 验证与家系分析。

表型侧的 **Alpha-mannosidosis**（Qwen 强调）在 Exomiser Top 基因中 **无直接对应**，宜作为独立生化检测方向，不宜仅凭 LLM 排在基因候选之前。

---

## 8. 总结

| 维度 | 结论 |
|------|------|
| 部署是否成功 | 是，本地 Qwen3-14B 完整跑通 HPO + VCF 流程 |
| 与 gpt-4o 一致性 | **基因融合 Top-3 一致**；表型路径差异大 |
| 可信度 | 基因 Top-3 两次等价；gpt-4o 的 #4–#5 更贴 Exomiser；Qwen 表型推理更易受相似病例影响 |
| 本地 Qwen 价值 | 可复现主结论、可离线、本例质量接近云端 |
| 报告建议 | 以 **KMT2C / ATP7A / SLC12A6** 为主；Alpha-mannosidosis 作补充检测；忽略 Qwen 中可疑 PMC 链接 |

### 一句话摘要

> 对 test_001（癫痫、听力障碍、白细胞增多），Exomiser 优先提示 KMT2C、ATP7A、SLC12A6 相关罕见病；gpt-4o 与本地 Qwen3-14B 在基因驱动诊断的前三名一致（Kleefstra syndrome 2、Menkes/OHS、ACC-PN），表明 DeepRare 基因推理链路在更换本地 LLM 后核心结论稳定。

---

## 9. 复现命令（参考）

**启动 Qwen 服务（GPU 5）：**

```bash
conda activate qwen3_infer
cd ~/DeepRare
export CUDA_VISIBLE_DEVICES=5
bash scripts/start_qwen_transformers.sh
```

**运行基因推理（GPU 0）：**

```bash
conda activate deeprare
export EMBED_APIKEY='sk-...'
export QWEN_MODEL='Qwen/Qwen3-14B'
export INFER_GPU=0
bash inference_gene_qwen.sh
```

**gpt-4o 对照：**

```bash
conda activate deeprare
export OPENAI_APIKEY='sk-...'
bash inference_gene.sh
```

---

## 附录：相关文件

| 类型 | 路径 |
|------|------|
| gpt-4o 结果 | `result_gene/case/gpt-4o/patient_0.json` |
| Qwen3-14B 结果 | `result_gene/case/Qwen_Qwen3-14B/patient_0.json` |
| Exomiser JSON | `result_gene/exomiser_results/diagnosis_result_test_001.json` |
| Exomiser HTML | `result_gene/exomiser_results/test_001.html` |

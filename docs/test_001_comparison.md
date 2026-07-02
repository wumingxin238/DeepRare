# test_001 对比分析：gpt-4o vs 本地 Qwen3-14B

> DeepRare 基因模式（HPO + VCF）单病例报告  
> 病例 ID：`test_001` · 日期：2026-06-16

---

## 1. 病例与运行设置

| 项目 | 内容 |
|------|------|
| 表型 (HPO) | Seizure (HP:0001250)、Hearing impairment (HP:0000365)、Leukocytosis (HP:0001974) |
| VCF | `./data/vcf/test_001.vcf` |
| 金标准 | 无 |

| 项目 | gpt-4o | Qwen3-14B |
|------|--------|-----------|
| 脚本 | `inference_gene.sh` | `inference_gene_qwen.sh` |
| 主 LLM | xiaoai `gpt-4o` | 本地 `Qwen/Qwen3-14B`（`:8000`） |
| Embedding | xiaoai `text-embedding-3-small` | 同左 |
| 耗时 | 209 s | 214 s |
| 主结果 | `result_gene/case/gpt-4o/patient_0.json` | `result_gene/case/Qwen_Qwen3-14B/patient_0.json` |

两次 PubCaseFinder / Phenobrain 输入相同，DuckDuckGo 均失败。Exomiser 共用 `exomiser_results/`；两份 `patient_0.json` 内嵌的 `exomiser_summary` **逐字相同**。

---

## 2. Exomiser 基因层（两次相同）

| 排名 | 基因 | 分数 | 关联疾病 | ClinVar |
|------|------|------|----------|---------|
| 1 | **KMT2C** | 0.942 | Kleefstra syndrome 2 | BENIGN_OR_LIKELY_BENIGN |
| 2 | **ATP7A** | 0.794 | Menkes / Occipital horn syndrome | CONFLICTING |
| 3 | **SLC12A6** | 0.769 | ACC-PN / CMT2II | UNCERTAIN |
| 4 | HPR | 0.763 | — | UNCERTAIN |
| 5 | DOCK5 | 0.757 | — | UNCERTAIN |

基因排名由 Exomiser 决定，与 LLM 无关。

---

## 3. 表型路径（融合基因前）

### 零样本 Top-5

| # | gpt-4o | Qwen3-14B |
|---|--------|-----------|
| 1 | Alpers-Huttenlocher | Cockayne syndrome |
| 2 | Cockayne syndrome | Rett syndrome |
| 3 | Muckle-Wells | Alström syndrome |
| 4 | Chediak-Higashi | Neuronal ceroid lipofuscinoses |
| 5 | Refsum disease | Mucolipidosis IV |

### 多轮初步诊断

| # | gpt-4o | Qwen3-14B |
|---|--------|-----------|
| 1 | **CVT** | **Alpha-mannosidosis** |
| 2 | Mitochondrial encephalomyopathy | MOG-IgG encephalitis |
| 3 | Neurosarcoidosis | CVT |
| 4 | Autoimmune encephalitis | HSP |
| 5 | Intracranial vasculitis | MELAS |

gpt-4o 更依赖 CVT 相似病例；Qwen 受 Alpha-mannosidosis、MOG、CVT 三个相似病例影响，表型路径分歧较大。

---

## 4. 最终诊断（Exomiser + 表型融合）

### Top-3（一致）

| # | gpt-4o | Qwen3-14B |
|---|--------|-----------|
| 1 | **Kleefstra syndrome 2** (KMT2C) | **Kleefstra syndrome 2** (KMT2C) |
| 2 | **Menkes disease** (ATP7A) | **OHS / Menkes** (ATP7A) |
| 3 | **ACC-PN** (SLC12A6) | **ACC-PN** (SLC12A6) |

### #4–#5（有差异）

| # | gpt-4o | Qwen3-14B |
|---|--------|-----------|
| 4 | Occipital horn syndrome (ATP7A) | Alpha-mannosidosis（Exomiser 未支持） |
| 5 | ACC-PN / CMT2II（SLC12A6） | HSP（表型弱支持） |

gpt-4o 的 #4–#5 更贴 Exomiser；Qwen 将表型候选 Alpha-mannosidosis 保留进最终列表。

---

## 5. 质量备注

| 模型 | 主要问题 |
|------|----------|
| Qwen3-14B | 表型阶段疑似编造 PMC 链接；引用 test_001 未提供的 MRI 等信息 |
| gpt-4o | Exomiser JSON 中 `model_used` 误标为 `deepseek-v3`（代码 bug）；表型过度依赖 CVT 相似病例 |
| 共同 | 知识库检索大量 `Not found`（环境/网络） |

Qwen 优点：对 KMT2C ClinVar「良性」有保留；能区分「基因支持」与「仅表型 plausible」。

---

## 6. 临床建议（无金标准）

验证优先级：

1. **KMT2C / Kleefstra syndrome 2** — Exomiser 最高，ClinVar 偏良性，需家系与功能验证  
2. **ATP7A（Menkes / OHS）** — 与癫痫、听力障碍较吻合  
3. **SLC12A6（ACC-PN）** — splice VUS，建议 RNA / 家系验证  

Alpha-mannosidosis 宜作独立生化检测，不宜仅凭 LLM 排在基因候选之前。

---

## 7. 总结

| 维度 | 结论 |
|------|------|
| 本地部署 | 成功，Qwen3-14B 完整跑通 HPO + VCF |
| 与 gpt-4o | **基因融合 Top-3 一致**；表型路径差异大 |
| 报告建议 | 以 KMT2C / ATP7A / SLC12A6 为主；Alpha-mannosidosis 作补充检测 |

> Exomiser 提示 KMT2C、ATP7A、SLC12A6；gpt-4o 与 Qwen3-14B 基因驱动 Top-3 一致，说明更换本地 LLM 后 DeepRare 基因模式主结论稳定。

---

## 附录

**相关文件**

| 文件 | 路径 |
|------|------|
| gpt-4o 结果 | `result_gene/case/gpt-4o/patient_0.json` |
| Qwen 结果 | `result_gene/case/Qwen_Qwen3-14B/patient_0.json` |
| Exomiser HTML | `result_gene/exomiser_results/test_001.html` |
| Exomiser 融合 JSON | `result_gene/exomiser_results/diagnosis_result_test_001.json`（最后一次运行，Qwen） |

**复现（服务器）**

```bash
# tmux 1：Qwen 服务
conda activate qwen3_infer && cd ~/DeepRare
export CUDA_VISIBLE_DEVICES=5 && bash scripts/start_qwen_transformers.sh

# tmux 2：推理
conda activate deeprare && cd ~/DeepRare
export EMBED_APIKEY='sk-...' QWEN_MODEL='Qwen/Qwen3-14B' INFER_GPU=0
bash inference_gene_qwen.sh
```

gpt-4o 对照：`bash inference_gene.sh`

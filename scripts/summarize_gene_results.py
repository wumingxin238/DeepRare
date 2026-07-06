#!/usr/bin/env python3
"""Summarize DeepRare gene-mode JSON results under result_gene/."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import defaultdict
from pathlib import Path


def extract_top_diagnoses(text: str, limit: int = 5) -> list[str]:
    if not text:
        return []
    numbered = re.findall(r"^\s*\d+\.\s*\*\*([^*]+)\*\*", text, re.MULTILINE)
    if numbered:
        return [x.strip() for x in numbered[:limit]]
    bold = re.findall(r"\*\*([^*]+)\*\*", text)
    out: list[str] = []
    for name in bold:
        name = name.strip()
        if name.lower().startswith("gene:"):
            continue
        if name in out:
            continue
        out.append(name)
        if len(out) >= limit:
            break
    return out


def extract_exomiser_genes(summary: str, limit: int = 5) -> list[str]:
    if not summary:
        return []
    genes = []
    for line in summary.splitlines():
        m = re.match(r"Gene:\s*(\S+)", line.strip())
        if m:
            genes.append(m.group(1))
    return genes[:limit]


def load_patient_json(path: Path) -> dict:
    with path.open(encoding="utf-8-sig") as f:
        return json.load(f)


def pick_block(data: dict, key: str) -> dict:
    block = data.get(key) or {}
    return block if isinstance(block, dict) else {}


def normalize_model_name(model_dir: str) -> str:
    m = re.search(r"models--Qwen--(.+?)(?:_snapshots_|$)", model_dir)
    if m:
        return f"Qwen/{m.group(1)}"
    if model_dir.startswith("Qwen_"):
        return model_dir.replace("Qwen_", "Qwen/", 1)
    return model_dir


def infer_sample_id(sample_id: str, vcf_path: str) -> str:
    sid = (sample_id or "").strip()
    if sid:
        return sid
    if not vcf_path:
        return ""
    stem = Path(vcf_path.replace("\\", "/")).name
    if stem.lower().endswith(".vcf"):
        stem = stem[:-4]
    return stem


def make_case_key(sample_id: str, vcf_path: str, phenotypes: str) -> str:
    sid = infer_sample_id(sample_id, vcf_path) or "unknown"
    if phenotypes:
        return f"{sid} | {phenotypes}"
    return sid


def parse_result_path(path: Path, result_dir: Path) -> tuple[str, str]:
    try:
        rel = path.relative_to(result_dir.resolve())
        if len(rel.parts) >= 3:
            return rel.parts[0], rel.parts[1]
    except ValueError:
        pass
    return path.parent.parent.name, path.parent.name


def summarize_one(path: Path, result_dir: Path) -> dict:
    data = load_patient_json(path)
    rnd = pick_block(data, "first_round_result") or pick_block(data, "final_diagnois")

    phenotypes_list = data.get("phenotypes") or []
    if not phenotypes_list and data.get("patient_info"):
        phenotypes_list = [p.strip() for p in str(data["patient_info"]).split(",") if p.strip()]
    phenotypes = "; ".join(phenotypes_list)

    exomiser_summary = rnd.get("exomiser_summary") or data.get("exomiser_summary") or ""
    ai_text = rnd.get("ai_diagnosis") or data.get("ai_diagnosis") or ""

    m = re.search(r"patient_(\d+)", path.stem)
    patient_idx = m.group(1) if m else path.stem

    dataset, model_dir = parse_result_path(path, result_dir)
    sample_id = infer_sample_id(rnd.get("sample_id") or "", rnd.get("vcf_path") or "")

    return {
        "dataset": dataset,
        "model_dir": model_dir,
        "model": normalize_model_name(model_dir),
        "patient": patient_idx,
        "case_key": make_case_key(sample_id, rnd.get("vcf_path") or "", phenotypes),
        "sample_id": sample_id,
        "file": str(path),
        "vcf_path": rnd.get("vcf_path") or "",
        "phenotypes": phenotypes,
        "golden_diagnosis": (data.get("golden_diagnosis") or "").strip(),
        "exomiser_genes": "; ".join(extract_exomiser_genes(exomiser_summary)),
        "top_diagnoses": "; ".join(extract_top_diagnoses(ai_text)),
        "model_used": rnd.get("model_used") or "",
        "time_sec": data.get("time_taken", ""),
    }


def find_result_files(scan_dir: Path, dataset: str | None) -> list[Path]:
    direct = sorted(scan_dir.glob("patient_*.json"))
    if direct:
        return direct
    if dataset:
        base = scan_dir / dataset
        files = sorted(base.glob("*/patient_*.json"))
        if files:
            return files
    return sorted(scan_dir.glob("*/*/patient_*.json"))


def sort_rows(rows: list[dict]) -> list[dict]:
    return sorted(rows, key=lambda r: (r["dataset"], r["case_key"], r["model"], r["patient"]))


def print_overview(rows: list[dict]) -> None:
    by_dataset: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        by_dataset[row["dataset"]].append(row)

    print("---")
    print("Overview")
    for ds in sorted(by_dataset):
        ds_rows = by_dataset[ds]
        case_keys = {r["case_key"] for r in ds_rows}
        print(f"  dataset={ds}: {len(ds_rows)} run(s), {len(case_keys)} unique case(s)")
        for case_key in sorted(case_keys):
            models = sorted({r["model"] for r in ds_rows if r["case_key"] == case_key})
            print(f"    - {case_key}  [{', '.join(models)}]")
    print()


def print_table(rows: list[dict]) -> None:
    if not rows:
        print("No patient_*.json found.", file=sys.stderr)
        return

    print(f"Total runs: {len(rows)}\n")
    for i, row in enumerate(rows, 1):
        print(
            f"[{i}] dataset={row['dataset']}  case={row['case_key']}  "
            f"model={row['model']}  patient_{row['patient']}"
        )
        print(f"    vcf        : {row['vcf_path'] or '-'}")
        print(f"    exomiser   : {row['exomiser_genes'] or '-'}")
        print(f"    top5 AI    : {row['top_diagnoses'] or '-'}")
        if row["golden_diagnosis"]:
            print(f"    gold       : {row['golden_diagnosis']}")
        if row["time_sec"] != "":
            print(f"    time(s)    : {float(row['time_sec']):.1f}")
        print(f"    json       : {row['file']}")
        print()

    print_overview(rows)


def write_csv(rows: list[dict], csv_path: Path) -> None:
    fields = [
        "dataset",
        "case_key",
        "model",
        "model_dir",
        "patient",
        "sample_id",
        "vcf_path",
        "phenotypes",
        "golden_diagnosis",
        "exomiser_genes",
        "top_diagnoses",
        "model_used",
        "time_sec",
        "file",
    ]
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with csv_path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    print(f"CSV saved: {csv_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Summarize DeepRare gene-mode results.")
    parser.add_argument(
        "--result-dir",
        type=Path,
        default=Path("result_gene"),
        help="Root result folder (default: result_gene)",
    )
    parser.add_argument(
        "--run-dir",
        type=Path,
        default=None,
        help="Single output folder with patient_*.json (e.g. result_gene/case/Qwen_Qwen3-14B)",
    )
    parser.add_argument(
        "--dataset",
        default="case",
        help="Dataset subfolder under result-dir (default: case; use '' for all)",
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=None,
        help="Optional CSV output path",
    )
    args = parser.parse_args()

    root = args.result_dir.resolve()
    if args.run_dir:
        scan_dir = args.run_dir.resolve()
    else:
        scan_dir = root

    if not scan_dir.is_dir():
        print(f"ERROR: not found: {scan_dir}", file=sys.stderr)
        sys.exit(1)

    dataset = None if args.run_dir else (args.dataset or None)
    files = find_result_files(scan_dir, dataset)
    rows = sort_rows([summarize_one(p, scan_dir) for p in files])
    print_table(rows)
    if args.csv:
        write_csv(rows, args.csv)


if __name__ == "__main__":
    main()

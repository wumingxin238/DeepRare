import json
import os
from datasets import load_dataset
from typing import Tuple, List, Dict, Any
import pandas as pd


def _load_rarebench_data(dataset_name: str, dataset_path: str) -> List[Dict[str, Any]]:
    local_jsonl = os.path.join('dataset', 'RareBench', 'data', f'{dataset_name}.jsonl')
    if os.path.exists(local_jsonl):
        records = []
        with open(local_jsonl, encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line:
                    records.append(json.loads(line))
        return records

    try:
        hf_data = load_dataset(dataset_path, dataset_name, split='test', trust_remote_code=True)
        return [row for row in hf_data]
    except RuntimeError as e:
        if 'Dataset scripts are no longer supported' in str(e):
            raise RuntimeError(
                f"Cannot load RareBench split '{dataset_name}' via HuggingFace scripts. "
                "Run:\n"
                "  mkdir -p dataset/RareBench && "
                "wget -O dataset/RareBench/data.zip "
                "https://huggingface.co/datasets/chenxz/RareBench/resolve/main/data.zip && "
                "unzip -o dataset/RareBench/data.zip -d dataset/RareBench"
            ) from e
        raise


class RarePrompt:
    def __init__(self) -> None:
        self.system_prompt = "You are a specialist in the field of rare diseases."
        self.diagnosis_system_prompt = self.system_prompt + \
                                    " You will be provided and asked about a complicated clinical case; \
                                        read it carefully and then provide a diverse and comprehensive differential diagnosis. \
                                        Also, you will be provided some knowledge about the patient's phenotype and online diagnosis suggestions as reference, please read it carefully."


    def diagnosis_prompt(self, patient_info: str) -> Tuple[str, str]:

        info_type = "phenotype"
        prompt = ""
        prompt += f"Patient's {info_type}: {patient_info}\n"
        prompt += "Enumerate the top 5 most likely diagnoses. Be precise, and try to cover many unique possibilities. "
        prompt += "Each diagnosis should be a rare disease. "
        prompt += "Use ## to tag the disease name. "
        prompt += "Make sure to reorder the diagnoses from most likely to least likely. "
        prompt += "The top 5 diagnoses are:"
        
        return (self.diagnosis_system_prompt, prompt)

class RareDataset():
    def __init__(self, args) -> None:
        self.dataset_name = args.dataset_name
        self.dataset_path = args.dataset_path
        self.phenotype_mapping = json.load(open(args.phenotype_mapping, "r", encoding="utf-8-sig"))
        self.disease_mapping = json.load(open(args.disease_mapping, "r", encoding="utf-8-sig"))

        if self.dataset_name in ["RAMEDIS", "MME", "HMS", "LIRICAL"]: 
            self.data = _load_rarebench_data(self.dataset_name, self.dataset_path)
        elif self.dataset_name == 'Xinhua':
            self.data = pd.read_csv('dataset/xinhua_test_0331.csv')
        elif self.dataset_name == 'MIMIC':
            self.data = pd.read_csv('dataset/mimic_test.csv', sep='|')
        elif self.dataset_name == 'mygene':
            self.data = pd.read_csv('dataset/mygene_test.csv')
        elif self.dataset_name == 'DDD':
            self.data = pd.read_csv('dataset/ddd_test.csv')
        elif self.dataset_name == 'case':
            self.data = pd.read_csv('dataset/cases.csv')
        elif self.dataset_name == 'hunan':
            self.data = pd.read_csv('dataset/hunan_cases.csv')

        self.patient = self.load_ehr_phenotype_data()

    def load_ehr_phenotype_data(self):

        patient = []

        if self.dataset_name in ["RAMEDIS", "MME", "HMS", "LIRICAL"]: 
            for p in self.data:
                phenotype_list = p['Phenotype']
                disease_list = p['RareDisease']

                phenotype_list_ = [self.phenotype_mapping[phenotype] for phenotype in phenotype_list if phenotype in self.phenotype_mapping]
                disease_list = [self.disease_mapping[disease] for disease in disease_list if disease in self.disease_mapping]
                phenotype_id = [phenotype for phenotype in phenotype_list if phenotype in self.phenotype_mapping]

                phenotype = ", ".join(phenotype_list_)
                disease = ", ".join(disease_list)
                patient.append((phenotype, disease, phenotype_list_, phenotype_id))

        elif self.dataset_name in ['MIMIC']:
            for p in self.data.iterrows():
                phenotype_list = eval(p[1]['HPO'])
                disease_list = eval(p[1]['orpha'])

                phenotype_list_ = [self.phenotype_mapping[phenotype] for phenotype in phenotype_list if phenotype in self.phenotype_mapping]
                disease_list = [self.disease_mapping[disease] for disease in disease_list if disease in self.disease_mapping]
                phenotype_id = [phenotype for phenotype in phenotype_list if phenotype in self.phenotype_mapping]

                phenotype = ", ".join(phenotype_list_)
                disease = ", ".join(disease_list)
                patient.append((phenotype, disease, phenotype_list_, phenotype_id))

        elif self.dataset_name in ['Xinhua']:
            for p in self.data.iterrows():
                phenotype_list = eval(p[1]['hpo'])
                disease_list = eval(p[1]['orpha'])

                phenotype_list_ = [self.phenotype_mapping[phenotype] for phenotype in phenotype_list if phenotype in self.phenotype_mapping]
                disease_list = [self.disease_mapping[disease] for disease in disease_list if disease in self.disease_mapping]
                phenotype_id = [phenotype for phenotype in phenotype_list if phenotype in self.phenotype_mapping]

                phenotype = ", ".join(phenotype_list_)
                disease = ", ".join(disease_list)
                if 'vcf_path' in p[1]:
                    vcf_path = p[1]['vcf_path']
                    patient.append((phenotype, disease, phenotype_list_, phenotype_id, vcf_path))
                else:
                    patient.append((phenotype, disease, phenotype_list_, phenotype_id))
                
        elif self.dataset_name in ['mygene', 'DDD']:
            for p in self.data.iterrows():
                phenotype_list = eval(p[1]['phenotype'])
                disease_list = eval(p[1]['rare_disease'])
                phenotype_list_ = [self.phenotype_mapping[phenotype] for phenotype in phenotype_list if phenotype in self.phenotype_mapping]
                disease_list = [self.disease_mapping[disease] for disease in disease_list if disease in self.disease_mapping]
                phenotype_id = [phenotype for phenotype in phenotype_list if phenotype in self.phenotype_mapping]
                phenotype = ", ".join(phenotype_list_)
                disease = ", ".join(disease_list)
                patient.append((phenotype, disease, phenotype_list_, phenotype_id))
        elif self.dataset_name in ['hunan']:
            for p in self.data.iterrows():
                phenotype_list = p[1]['hpo'].split('|')
                disease_list = eval(p[1]['disease'])
                phenotype_list_ = [self.phenotype_mapping[phenotype] for phenotype in phenotype_list if phenotype in self.phenotype_mapping]
                disease_list = disease_list  # Assuming diseases are already in readable format
                phenotype_id = [phenotype for phenotype in phenotype_list if phenotype in self.phenotype_mapping]
                phenotype = ", ".join(phenotype_list_)
                disease = ", ".join(disease_list)
                if 'vcf_path' in p[1]:
                    vcf_path = p[1]['vcf_path']
                    patient.append((phenotype, disease, phenotype_list_, phenotype_id, vcf_path))
                else:
                    patient.append((phenotype, disease, phenotype_list_, phenotype_id))
        elif self.dataset_name in ['case']:
            for p in self.data.iterrows():
                hpo_raw = p[1]['hpo']
                if isinstance(hpo_raw, str) and hpo_raw.strip().startswith('['):
                    phenotype_list = eval(hpo_raw)
                else:
                    phenotype_list = [x.strip() for x in str(hpo_raw).split('|') if x.strip()]

                disease_raw = p[1].get('disease', '[]')
                if pd.isna(disease_raw) or disease_raw == '':
                    disease_list = []
                elif isinstance(disease_raw, str) and disease_raw.strip().startswith('['):
                    disease_list = eval(disease_raw)
                else:
                    disease_list = [str(disease_raw)]

                phenotype_list_ = [self.phenotype_mapping[phenotype] for phenotype in phenotype_list if phenotype in self.phenotype_mapping]
                disease_list = [self.disease_mapping[disease] for disease in disease_list if disease in self.disease_mapping]
                phenotype_id = [phenotype for phenotype in phenotype_list if phenotype in self.phenotype_mapping]
                phenotype = ", ".join(phenotype_list_)
                disease = ", ".join(disease_list)
                vcf_path = p[1]['vcf_path']
                patient.append((phenotype, disease, phenotype_list_, phenotype_id, vcf_path))
                
        return patient
            
            
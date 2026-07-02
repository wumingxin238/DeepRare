# HPO + VCF inference (requires Exomiser)
export PYTHONFAULTHANDLER=1
export CUDA_VISIBLE_DEVICES=0

DATASET_NAME="case"

OPENAI_BASE_URL="https://xiaoai.plus/v1"
OPENAI_APIKEY="sk-0KdA7qGS7hq6k2ET6PFDKiIecav56NHlY5lPwfnrtC3WdeHk"

# Exomiser (install per README; VCF is GRCh37/hg19)
EXOMISER_JAR="./exomizer-cli-14.1.0/exomiser-cli-14.1.0.jar"

python main_gene.py \
    --model openai \
    --dataset_name $DATASET_NAME \
    --search_engine duckduckgo \
    --openai_apikey $OPENAI_APIKEY \
    --openai_base_url $OPENAI_BASE_URL \
    --openai_model gpt-4o \
    --results_folder ./result_gene \
    --exomiser_jar $EXOMISER_JAR \
    --exomiser_save_path exomiser_results/

# bash inference_gene.sh

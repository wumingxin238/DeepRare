# Description: Inference script for running the model on a single input
export PYTHONFAULTHANDLER=1
export CUDA_VISIBLE_DEVICES=1

# ChromeDriver Service Path
SERVICE_PATH="/usr/local/bin/chromedriver"

# google search engine (only used when --search_engine google)
SEARCH_ID="74f79cca226f84352"
GOOGLE_API="Your_Google_API_Key_Here"

# dataset name (HMS loads test cases from HuggingFace chenxz/RareBench)
DATASET_NAME="HMS"

# xiaoai.plus OpenAI-compatible proxy (gpt-4o / gpt-4o-mini / text-embedding-3-small)
OPENAI_BASE_URL="https://xiaoai.plus/v1"
OPENAI_APIKEY="sk-0KdA7qGS7hq6k2ET6PFDKiIecav56NHlY5lPwfnrtC3WdeHk"

DEEPSEEK_APIKEY=""
GEMINI_APIKEY=""
CLAUDE_APIKEY=""

python main.py \
    --model openai \
    --dataset_name $DATASET_NAME \
    --search_engine bing \
    --openai_apikey $OPENAI_APIKEY \
    --openai_base_url $OPENAI_BASE_URL \
    --openai_model gpt-4o \
    --deepseek_apikey $DEEPSEEK_APIKEY \
    --deepseek_model deepseek-v3-241226 \
    --gemini_apikey $GEMINI_APIKEY \
    --gemini_model gemini-2.0-flash \
    --claude_apikey $CLAUDE_APIKEY \
    --claude_model claude-3-7-sonnet-20250219 \
    --chrome_driver $SERVICE_PATH \
    --google_api $GOOGLE_API \
    --search_engine_id $SEARCH_ID \
    --results_folder ./result \

# To run the inference script, use the following command:
# bash inference.sh

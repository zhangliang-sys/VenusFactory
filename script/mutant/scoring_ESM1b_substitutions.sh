#!/bin/bash
#PBS -q ai3090
#PBS -l walltime=168:00:00
#PBS -l select=1:ncpus=6:ngpus=1:mem=16gb
#PBS -N scoring_ESM1b_substitutions
#PBS -o /home/zliang/project/proteinsquare/scripts/pbs/log/o
#PBS -e /home/zliang/project/proteinsquare/scripts/pbs/log/e

module load  cuda/11.7
cd $PBS_O_WORKDIR

source /home/zliang/project/proteinsquare/ProteinGym/scripts/small_zero_shot_config.sh
source /home/zliang/new_anaconda/anaconda3/etc/profile.d/conda.sh

conda activate proteingym

# ESM1b参数设置
export model_checkpoint="/home/zliang/project/proteinsquare/checkpoints/esm1b/esm1b_t33_650M_UR50S.pt"
export dms_output_folder="${DMS_output_score_folder_subs}/ESM1b/"

# 固定参数
export model_type="ESM1b"
export scoring_strategy="wt-marginals"
export scoring_window="overlapping"

total_lines=$(( $(wc -l < ${DMS_reference_file_path_subs}) - 1 ))
echo "Total number of entries to process: ${total_lines}"

for DMS_index in $(seq 0 $((total_lines-1)))
do

        # 获取当前蛋白的名称
    protein_name=$(awk -F',' -v idx=$((DMS_index+1)) 'NR==idx+1 {print $1}' ${DMS_reference_file_path_subs})
    output_file="${dms_output_folder}/${protein_name}.csv"
        # 检查输出文件是否已存在
    if [ -f "$output_file" ]; then
        echo "Skipping DMS_index: ${DMS_index} (${protein_name}), prediction file already exists"
        continue
    fi
    echo "Processing DMS_index: ${DMS_index}"
    
    python /home/zliang/project/proteinsquare/ProteinGym/proteingym/baselines/esm/compute_fitness.py \
        --model-location ${model_checkpoint} \
        --model_type ${model_type} \
        --dms_index ${DMS_index} \
        --dms_mapping ${DMS_reference_file_path_subs} \
        --dms-input ${DMS_data_folder_subs} \
        --dms-output ${dms_output_folder} \
        --scoring-strategy ${scoring_strategy} \
        --scoring-window ${scoring_window}
    
    # 错误检查
    if [ $? -ne 0 ]; then
        echo "Error processing DMS_index: ${DMS_index}"
        echo ${DMS_index} >> esm1b_failed_indices.txt
    fi
    
    # 添加短暂延迟
    sleep 1
done

echo "All DMS indices processed"
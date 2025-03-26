#!/bin/bash
#PBS -q ai4090
#PBS -l walltime=168:00:00
#PBS -l select=1:ncpus=6:ngpus=1:mem=16gb
#PBS -N scoring_RITA_substitutions
#PBS -o /home/zliang/project/proteinsquare/scripts/pbs/log/o
#PBS -e /home/zliang/project/proteinsquare/scripts/pbs/log/e

module load  cuda/11.7
cd $PBS_O_WORKDIR

source /home/zliang/project/proteinsquare/ProteinGym/scripts/small_zero_shot_config.sh
source /home/zliang/new_anaconda/anaconda3/etc/profile.d/conda.sh

conda activate proteingym

# 设置模型和输出路径
# 不同大小模型的配置（注释掉不用的）
# export RITA_model_path="../../../checkpoints/RITA/small"
# export output_scores_folder="${DMS_output_score_folder_subs}/RITA/small"

# export RITA_model_path="../../../checkpoints/RITA/medium"
# export output_scores_folder="${DMS_output_score_folder_subs}/RITA/medium"

# export RITA_model_path="../../../checkpoints/RITA/large"
# export output_scores_folder="${DMS_output_score_folder_subs}/RITA/large"

export RITA_model_path="/home/zliang/project/proteinsquare/checkpoints/RITA/xlarge"
export output_scores_folder="${DMS_output_score_folder_subs}/RITA/xlarge"

total_lines=$(( $(wc -l < ${DMS_reference_file_path_subs}) - 1 ))
echo "Total number of entries to process: ${total_lines}"

for DMS_index in $(seq 0 $((total_lines-1)))
do
    # 获取当前蛋白的名称
    protein_name=$(awk -F',' -v idx=$((DMS_index+1)) 'NR==idx+1 {print $1}' ${DMS_reference_file_path_subs})
    output_file="${output_scores_folder}/${protein_name}.csv"
        # 检查输出文件是否已存在
    if [ -f "$output_file" ]; then
        echo "Skipping DMS_index: ${DMS_index} (${protein_name}), prediction file already exists"
        continue
    fi
    echo "Processing DMS_index: ${DMS_index}"
    
    python /home/zliang/project/proteinsquare/ProteinGym/proteingym/baselines/rita/compute_fitness.py \
        --RITA_model_name_or_path ${RITA_model_path} \
        --DMS_reference_file_path ${DMS_reference_file_path_subs} \
        --DMS_data_folder ${DMS_data_folder_subs} \
        --DMS_index ${DMS_index} \
        --output_scores_folder ${output_scores_folder}
    
    # 错误检查
    if [ $? -ne 0 ]; then
        echo "Error processing DMS_index: ${DMS_index}"
        echo ${DMS_index} >> rita_failed_indices.txt
    fi
    
    # 添加短暂延迟
    sleep 1
done

echo "All DMS indices processed"
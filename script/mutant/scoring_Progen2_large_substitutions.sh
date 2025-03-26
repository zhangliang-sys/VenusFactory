#!/bin/bash
#PBS -q ai4090
#PBS -l walltime=168:00:00
#PBS -l select=1:ncpus=6:ngpus=1:mem=16gb
#PBS -N scoring_Progen2_substitutions
#PBS -o /home/zliang/project/proteinsquare/scripts/pbs/log/o
#PBS -e /home/zliang/project/proteinsquare/scripts/pbs/log/e

module load cuda/11.7
cd $PBS_O_WORKDIR

source /home/zliang/project/proteinsquare/ProteinGym/scripts/small_zero_shot_config.sh
source /home/zliang/new_anaconda/anaconda3/etc/profile.d/conda.sh

conda activate proteingym

# 设置模型和输出路径
# export Progen2_model_name_or_path="/home/zliang/project/proteinsquare/checkpoints/progen2/small"
# export output_scores_folder="${DMS_output_score_folder_subs}/Progen2/small"

# 其他模型配置（注释掉）
# export Progen2_model_name_or_path="/home/zliang/project/proteinsquare/checkpoints/progen2/medium"
# export output_scores_folder="${DMS_output_score_folder_subs}/Progen2/medium"
 
# export Progen2_model_name_or_path="/home/zliang/project/proteinsquare/checkpoints/progen2/base"
# export output_scores_folder="${DMS_output_score_folder_subs}/Progen2/base"

export Progen2_model_name_or_path="/home/zliang/project/proteinsquare/checkpoints/progen2/large"
export output_scores_folder="${DMS_output_score_folder_subs}/Progen2/large"
 
# export Progen2_model_name_or_path="../../../checkpoints/progen2/xlarge"
# export output_scores_folder="${DMS_output_score_folder_subs}/Progen2/xlarge"

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
    
    python /home/zliang/project/proteinsquare/ProteinGym/proteingym/baselines/progen2/compute_fitness.py \
        --Progen2_model_name_or_path ${Progen2_model_name_or_path} \
        --DMS_reference_file_path ${DMS_reference_file_path_subs} \
        --DMS_data_folder ${DMS_data_folder_subs} \
        --DMS_index ${DMS_index} \
        --output_scores_folder ${output_scores_folder}
    
    # 错误检查
    if [ $? -ne 0 ]; then
        echo "Error processing DMS_index: ${DMS_index}"
        echo ${DMS_index} >> progen2_failed_indices.txt
    fi
    
    # 添加短暂延迟
    sleep 1
done

echo "All DMS indices processed"
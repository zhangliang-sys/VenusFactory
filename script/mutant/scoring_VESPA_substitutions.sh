#!/bin/bash
#PBS -q ai4090
#PBS -l walltime=168:00:00
#PBS -l select=1:ncpus=6:ngpus=1:mem=16gb
#PBS -o /home/zliang/project/proteinsquare/scripts/pbs/log/o
#PBS -e /home/zliang/project/proteinsquare/scripts/pbs/log/e

module load cuda/11.7
cd $PBS_O_WORKDIR

source /home/zliang/project/proteinsquare/ProteinGym/scripts/small_zero_shot_config.sh
source /home/zliang/new_anaconda/anaconda3/etc/profile.d/conda.sh

conda activate proteingym

# Ranges of DMSs to score in one run of VESPA 
# export DMS_index_range_start="2"
# export DMS_index_range_end="2"
# export vespa_cache='/home/zliang/project/proteinsquare/checkpoints/VESPA/prot_t5_xl_uniref50'
export vespa_cache='/home/zliang/project/proteinsquare/checkpoints/VESPA/prot_t5_xl_uniref50'
export output_scores_folder=${DMS_output_score_folder_subs}/VESPA


total_lines=$(( $(wc -l < ${DMS_reference_file_path_subs}) - 1 ))
echo "Total number of entries to process: ${total_lines}"

# 创建输出目录（如果不存在）
# mkdir -p ${DMS_output_score_folder}

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
    echo "Processing DMS_index: ${DMS_index} (${protein_name})"
    python /home/zliang/project/proteinsquare/ProteinGym/proteingym/baselines/vespa/compute_fitness.py \
        --cache_location $vespa_cache \
        --DMS_reference_file_path $DMS_reference_file_path_subs \
        --MSA_data_folder $DMS_MSA_a3m_data_folder \
        --DMS_data_folder $DMS_data_folder_subs \
        --DMS_index_range_start $DMS_index \
        --DMS_index_range_end $DMS_index

            # 添加错误检查
    if [ $? -ne 0 ]; then
        echo "Error processing DMS_index: ${DMS_index}"
        # 可选：记录失败的索引
        echo ${DMS_index} >> vespa_failed_indices.txt
    fi
    
    # 可选：添加短暂延迟，避免系统负载过高
    sleep 1
done

echo "All DMS indices processed"

#!/bin/bash
#PBS -q ai3090
#PBS -l walltime=168:00:00
#PBS -l select=1:ncpus=6:ngpus=1:mem=16gb
#PBS -o /home/zliang/project/proteinsquare/scripts/pbs/log/o
#PBS -e /home/zliang/project/proteinsquare/scripts/pbs/log/e

module load  cuda/11.7
# cd $PBS_O_WORKDIR


SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source ${SCRIPT_DIR}/config.sh
source /home/zliang/new_anaconda/anaconda3/etc/profile.d/conda.sh

conda activate proteingym

# if [ -f "$output_file" ]; then
# export model_name="carp_640M.pt" #[carp_600k|carp_38M|carp_76M|carp_640M]
# 定义目标目录
target_dir="../../dataset/ckpt/CARP/640M"

# 如果目录不存在，则创建
if [ ! -d "$target_dir" ]; then
    mkdir -p "$target_dir"
    echo "目录已创建：$target_dir"
else
    echo "目录已存在：$target_dir"
fi

# 设置环境变量
export model_path="${target_dir}/carp_640M.pt"
model_name="${target_dir}/carp_640M.pt"


# if [ -f "$model_path" ]; then
#     model_name=model_path
# else
#     model_name="carp_640M"
# fi


export DMS_output_score_folder=${DMS_output_score_folder_subs}/CARP
# export performance_file='CARP_640M_performance.csv'

total_lines=$(( $(wc -l < ${DMS_reference_file_path_subs}) - 1 ))
echo "Total number of entries to process: ${total_lines}"

for DMS_index in $(seq 0 $((total_lines-1)))
do
        # 获取当前蛋白的名称
    protein_name=$(awk -F',' -v idx=$((DMS_index+1)) 'NR==idx+1 {print $1}' ${DMS_reference_file_path_subs})
    output_file="${DMS_output_score_folder}/${protein_name}.csv"
        # 检查输出文件是否已存在
    if [ -f "$output_file" ]; then
        echo "Skipping DMS_index: ${DMS_index} (${protein_name}), prediction file already exists"
        continue
    fi
    
    echo "Processing DMS_index: ${DMS_index}"
    python3 ../../src/mutant/carp_mif/compute_fitness.py \
            --model_name ${model_name} \
            --model_path ${model_path} \
            --DMS_reference_file_path ${DMS_reference_file_path_subs} \
            --DMS_data_folder ${DMS_data_folder_subs} \
            --DMS_index ${DMS_index}  \
            --output_scores_folder ${DMS_output_score_folder} \
            # --performance_file ${performance_file} 
            # 添加错误检查
    # if [ $? -ne 0 ]; then
    #     echo "Error processing DMS_index: ${DMS_index}"
    #     # 可选：记录失败的索引
    #     echo ${DMS_index} >> carp_failed_indices.txt
    # fi
    
    # 可选：添加短暂延迟，避免系统负载过高
    sleep 1
done

echo "All DMS indices processed"

# /home/zliang/project/proteinsquare/ProteinGym/scripts/scoring_small_zero_shot/rename_carp_column.sh

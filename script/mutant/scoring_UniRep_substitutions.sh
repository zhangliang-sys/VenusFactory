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

conda activate protein_fitness_prediction
# source activate protein_fitness_prediction_hsu

export OMP_NUM_THREADS=1

export model_path="/home/zliang/project/proteinsquare/checkpoints/UniRep/1900_weights"
export output_scores_folder=${DMS_output_score_folder_subs}/UniRep
# export DMS_index="2"

total_lines=$(( $(wc -l < ${DMS_reference_file_path_subs}) - 1 ))
echo "Total number of entries to process: ${total_lines}"

# 创建输出目录（如果不存在）
mkdir -p ${output_scores_folder}
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

    python /home/zliang/project/proteinsquare/ProteinGym/proteingym/baselines/unirep/unirep_inference.py \
                --model_path $model_path \
                --data_path $DMS_data_folder_subs \
                --output_dir $output_scores_folder \
                --mapping_path $DMS_reference_file_path_subs \
                --DMS_index $DMS_index \
                --batch_size 8
    
    if [ $? -ne 0 ]; then
        echo "Error processing DMS_index: ${DMS_index}"
        # 可选：记录失败的索引
        echo ${DMS_index} >> unirep_failed_indices.txt
    fi
    
    # 可选：添加短暂延迟，避免系统负载过高
    sleep 1
done

echo "All DMS indices processed"

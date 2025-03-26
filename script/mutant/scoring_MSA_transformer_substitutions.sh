#!/bin/bash
#PBS -q ai4090
#PBS -l walltime=168:00:00
#PBS -l select=1:ncpus=6:ngpus=1:mem=32gb
#PBS -o /home/zliang/project/proteinsquare/scripts/pbs/log/o
#PBS -e /home/zliang/project/proteinsquare/scripts/pbs/log/e

module load cuda/11.7
cd $PBS_O_WORKDIR

source /home/zliang/project/proteinsquare/ProteinGym/scripts/small_zero_shot_config.sh
source /home/zliang/new_anaconda/anaconda3/etc/profile.d/conda.sh

conda activate proteingym

# MSA transformer checkpoint 
export model_checkpoint="esm_msa1b_t12_100M_UR50S"

export dms_output_folder="${DMS_output_score_folder_subs}/MSA_Transformer/"
export scoring_strategy=masked-marginals # MSA transformer only supports "masked-marginals"
export model_type=MSA_transformer
export scoring_window="optimal"
export random_seeds="1 2 3 4 5"
# export DMS_MSA_weights_for_MSA_Transformer_folder="${DMS_MSA_weights_folder}/DMS_msa_weights_for_MSA_Transformer" # Use weights recomputed post MSA filtering used in MSA Transformer
export DMS_MSA_weights_for_MSA_Transformer_folder="/home/zliang/project/proteinsquare/data/MSA/small_MSA_weights_for_MSA_Transformer"
export msa_sampling_strategy="sequence-reweighting"


total_lines=$(( $(wc -l < ${DMS_reference_file_path_subs}) - 1 ))
echo "Total number of entries to process: ${total_lines}"

# 创建输出目录（如果不存在）
mkdir -p ${dms_output_folder}
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
        --scoring-window ${scoring_window} \
        --msa-path ${DMS_MSA_data_folder} \
        --msa-sampling-strategy ${msa_sampling_strategy} \
        --msa-weights-folder ${DMS_MSA_weights_for_MSA_Transformer_folder} \
        --seeds ${random_seeds}

    if [ $? -ne 0 ]; then
        echo "Error processing DMS_index: ${DMS_index}"
        # 可选：记录失败的索引
        echo ${DMS_index} >> msa_transformer_failed_indices.txt
    fi
    
    # 可选：添加短暂延迟，避免系统负载过高
    sleep 1
done

echo "All DMS indices processed"

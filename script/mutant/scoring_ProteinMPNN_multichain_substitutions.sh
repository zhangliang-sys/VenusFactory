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

# 设置输出目录
export output_scores_folder=${DMS_output_score_folder_subs}/ProteinMPNN-multichain

# 设置模型路径
export model_checkpoint="/home/zliang/project/proteinsquare/checkpoints/ProteinMPNN/vanilla_model_weights/v_48_002.pt"

# 获取复合物结构目录中的所有PDB文件名（不包含路径和扩展名）
complex_pdbs=($(ls ${DMS_complex_structure_folder}/*.pdb | xargs -n 1 basename | sed 's/\.pdb$//'))

total_lines=$(( $(wc -l < ${DMS_reference_file_path_subs}) - 1 ))
echo "Total number of entries to process: ${total_lines}"

# 创建输出目录
mkdir -p ${output_scores_folder}

for DMS_index in $(seq 0 $((total_lines-1)))
do
    # 获取当前蛋白的名称
    protein_name=$(awk -F',' -v idx=$((DMS_index+1)) 'NR==idx+1 {print $1}' ${DMS_reference_file_path_subs})
    
    # 检查当前蛋白是否在complex_pdbs列表中
    if [[ ! " ${complex_pdbs[@]} " =~ " ${protein_name} " ]]; then
        continue
    fi
    
    # 从文件名中提取链ID（假设格式为xxx_ChainID_xxx）
    chain_id=$(echo $protein_name | grep -o '_[A-Z]_' | tr -d '_')
    if [ -z "$chain_id" ]; then
        echo "Warning: Could not extract chain ID from ${protein_name}"
        continue
    fi
    
    output_file="${output_scores_folder}/${protein_name}.csv"
    
    # 检查输出文件是否已存在
    if [ -f "$output_file" ]; then
        echo "Skipping DMS_index: ${DMS_index} (${protein_name}), prediction file already exists"
        continue
    fi
    
    echo "Processing complex: ${protein_name} (Chain ${chain_id}, DMS_index: ${DMS_index})"
    
    python /home/zliang/project/proteinsquare/ProteinGym/proteingym/baselines/protein_mpnn/compute_fitness.py \
        --checkpoint ${model_checkpoint} \
        --structure_folder ${DMS_complex_structure_folder} \
        --DMS_index $DMS_index \
        --DMS_reference_file_path ${DMS_reference_file_path_subs} \
        --DMS_data_folder ${DMS_data_folder_subs} \
        --output_scores_folder ${output_scores_folder} \
        --pdb_path_chains ${chain_id} \
        --batch_size 1

    # 错误检查
    if [ $? -ne 0 ]; then
        echo "Error processing complex: ${protein_name}"
        echo "${protein_name},${DMS_index}" >> proteinmpnn_multichain_failed_indices.txt
    fi
    
    # 添加短暂延迟
    sleep 1
done

echo "All complex structures processed"
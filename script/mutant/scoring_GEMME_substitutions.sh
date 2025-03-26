#!/bin/bash
#PBS -q huge
#PBS -l walltime=168:00:00
#PBS -l select=1:ncpus=8:mem=32gb
#PBS -o /home/zliang/project/proteinsquare/scripts/pbs/log/o
#PBS -e /home/zliang/project/proteinsquare/scripts/pbs/log/e

module load singularity/4.0.0 gemme/exe
cd $PBS_O_WORKDIR

source /home/zliang/project/proteinsquare/ProteinGym/scripts/small_zero_shot_config.sh
source /home/zliang/new_anaconda/anaconda3/etc/profile.d/conda.sh

# conda deactivate
conda activate proteingym

/home/zliang/project/proteinsquare/ProteinGym/scripts/scoring_small_zero_shot/reformat_GEMME_MSA.sh


export GEMME_MSA_data_folder="/home/zliang/project/proteinsquare/data/MSA/small_GEMME_MSA"

# GEMME路径设置
export GEMME_LOCATION="/global/software/GEMME"
export JET2_LOCATION="/home/zliang/software/JET2" 

export TEMP_FOLDER="/home/zliang/project/proteinsquare/ProteinGym/proteingym/baselines/gemme/gemme_tmp"
export DMS_output_score_folder="${DMS_output_score_folder_subs}/GEMME/"


total_lines=$(( $(wc -l < ${DMS_reference_file_path_subs}) - 1 ))
echo "Total number of entries to process: ${total_lines}"

# 创建输出目录（如果不存在）
mkdir -p ${DMS_output_score_folder}
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

    python /home/zliang/project/proteinsquare/ProteinGym/proteingym/baselines/gemme/compute_fitness.py --DMS_index=$DMS_index --DMS_reference_file_path=$DMS_reference_file_path_subs \
    --DMS_data_folder=$DMS_data_folder_subs --MSA_folder=$GEMME_MSA_data_folder --output_scores_folder=$DMS_output_score_folder \
    --GEMME_path=$GEMME_LOCATION --JET_path=$JET2_LOCATION --temp_folder=$TEMP_FOLDER

    if [ $? -ne 0 ]; then
        echo "Error processing DMS_index: ${DMS_index}"
        # 可选：记录失败的索引
        echo ${DMS_index} >> gemme_failed_indices.txt
    fi
    
    # 可选：添加短暂延迟，避免系统负载过高
    sleep 1
done

echo "All DMS indices processed"




# #!/bin/bash
# #PBS -q huge
# #PBS -l select=1:ncpus=4:mem=16gb
# #PBS -l walltime=168:00:00

# cd $PBS_O_WORKDIR


# module load singularity/4.0.0 gemme/exe
# gemme_path="/global/software/GEMME"

# a3m="/home/zliang/project/proteinsquare/data/MSA/small_a3m/1MLC_2_Kd-wtKd-mut"
# mutation="/home/zliang/project/proteinsquare/data/GEMME_sub/1MLC_2_Kd-wtKd-mut.csv" #只要一列突变点，不要有标题行

# fasta_dir="/home/zliang/project/proteinsquare/data/MSA/small_GEMME_MSA/1MLC_2_Kd-wtKd-mut.fasta"


# # prefix=$(basename "$a3m" .a3m)
# #path="${PBS_O_WORKDIR}/"
# #######  convert a3m to  fasta ########
# singularity exec --bind $gemme_path $gemme convertAli.sh $a3m  
# mv /home/zliang/project/proteinsquare/data/MSA/small_a3m/*.fasta /home/zliang/project/proteinsquare/data/MSA/small_GEMME_MSA/
# singularity exec --bind $gemme_path $gemme python $gemme_path/gemme.py $fasta_dir -r input -f $fasta_dir -n 3 -m ${mutation}

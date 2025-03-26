#%%
import os
from tranception.utils.msa_utils import MSA_processing
from tqdm import tqdm

def process_all_msas(msa_dir, weights_dir, theta=0.2):
    """
    为指定目录下的所有MSA文件生成权重
    
    参数:
    msa_dir: MSA文件所在目录
    weights_dir: 权重文件输出目录
    theta: 序列权重超参数
    """
    
    # 创建权重输出目录
    os.makedirs(weights_dir, exist_ok=True)
    
    # 获取所有.a2m文件
    msa_files = [f for f in os.listdir(msa_dir) if f.endswith('.a2m')]
    
    # 处理每个MSA文件
    for msa_file in tqdm(msa_files, desc="Processing MSA files"):
        try:
            # 构建输入输出路径
            msa_path = os.path.join(msa_dir, msa_file)
            weight_path = os.path.join(weights_dir, msa_file.replace('.a2m', '_weights.npy'))
            
            # 如果权重文件已存在则跳过
            if os.path.exists(weight_path):
                continue
                
            # 处理MSA并生成权重
            msa_processor = MSA_processing(
                MSA_location=msa_path,
                use_weights=True,
                weights_location=weight_path,
                theta=theta,
                preprocess_MSA=True,
                threshold_sequence_frac_gaps=0.5,
                threshold_focus_cols_frac_gaps=1.0,
                remove_sequences_with_indeterminate_AA_in_focus_cols=True
            )
            
            print(f"Successfully processed {msa_file}")
            
        except Exception as e:
            print(f"Error processing {msa_file}: {str(e)}")
            continue

if __name__ == "__main__":
   # 设置路径
    MSA_DIR = "/home/zliang/project/proteinsquare/data/MSA/proteingym_MSA/aa_seq_aln_a2m"
    WEIGHTS_DIR = "/home/zliang/project/proteinsquare/data/MSA/proteingym_MSA_weights"
    os.makedirs(WEIGHTS_DIR, exist_ok=True)
    
    # 处理所有MSA文件
    process_all_msas(
        msa_dir=MSA_DIR,
        weights_dir=WEIGHTS_DIR,
        theta=0.2  # 对于蛋白质家族使用0.2,对病毒使用0.01
    )
# %%

#!/usr/bin/env python3

import pandas as pd
from pathlib import Path
import logging

def setup_logging():
    """设置日志"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )

def rename_carp_column():
    """重命名CARP输出文件中的预测值列名"""
    # 定义路径
    carp_dir = Path("/home/zliang/project/proteinsquare/output/small/CARP")
    
    # 统计计数
    processed_count = 0
    error_count = 0
    
    # 处理所有CSV文件
    for file_path in carp_dir.glob("*.csv"):
        try:
            # 读取CSV文件
            df = pd.read_csv(file_path)
            
            # 检查原列名是否存在
            old_col = "/home/zliang/project/proteinsquare/checkpoints/CARP/640M/carp_640M.pt_score"
            if old_col not in df.columns:
                logging.warning(f"文件 {file_path.name} 中没有找到列 '{old_col}'")
                error_count += 1
                continue
            
            # 重命名列
            df = df.rename(columns={old_col: "carp_640M"})
            
            # 保存文件
            df.to_csv(file_path, index=False)
            logging.info(f"成功处理文件: {file_path.name}")
            processed_count += 1
            
        except Exception as e:
            logging.error(f"处理文件 {file_path.name} 时出错: {str(e)}")
            error_count += 1
    
    # 打印统计信息
    print("\n处理完成！")
    print("-" * 50)
    print(f"成功处理: {processed_count} 个文件")
    print(f"处理失败: {error_count} 个文件")
    print("-" * 50)

if __name__ == "__main__":
    setup_logging()
    rename_carp_column()
# This file has all general filepaths and directories used in the scoring pipeline. The individual scripts may have 
# additional parameters specific to each method 

# DMS zero-shot parameters

# Folders containing the csvs with the variants for each DMS assay
# export DMS_data_folder_subs="../../../data/DMS_ProteinGym_substitutions/"    #Folder containing DMS substitution csvs
export DMS_data_folder_subs="../../dataset/mutant/"
# export complex_DMS_data_folder_subs="/home/zliang/project/proteinsquare/data/complex_small_sub/"
# export DMS_data_folder_indels="Folder containing DMS indel csvs"

# Folders containing multiple sequence alignments and MSA weights for all DMS assays
export DMS_MSA_data_folder="/home/zliang/project/proteinsquare/data/MSA/small_a2m"
export DMS_MSA_a3m_data_folder="/home/zliang/project/proteinsquare/data/MSA/small_a3m"
export DMS_MSA_weights_folder="/home/zliang/project/proteinsquare/data/MSA/small_a2m_weights"

# Reference files for substitution and indel assays
# export DMS_reference_file_path_subs=../../reference_files/DMS_substitutions.csv
# export DMS_reference_file_path_subs=/home/zliang/project/proteinsquare/ProteinGym/reference_files/small_sub.csv
export DMS_reference_file_path_subs=/home/zliang/project/proteinsquare/ProteinGym/reference_files/small_pdb_avail_sub.csv
# export DMS_reference_file_path_indels=../../reference_files/DMS_indels.csv

# Folders where fitness predictions for baseline models are saved 
export DMS_output_score_folder_subs="../../result/mutant"  #folder for DMS substitution scores
# export DMS_output_score_folder_indels="folder for DMS indel scores"

# Folders containing merged score files for each DMS assay
export DMS_merged_score_folder_subs="folder for merged scores for DMS substitutions"
# export DMS_merged_score_folder_indels="folder for merged score for DMS indels"

# Folders containing predicted structures for the DMSs 
export DMS_structure_folder="/home/zliang/project/proteinsquare/data/pdb/pdb_only"
export DMS_complex_structure_folder="/home/zliang/project/proteinsquare/data/pdb/pdb_complex"
export PPB-Affinity_single-chain_structure_folder="/home/zliang/project/proteinsquare/data/pdb/PPB-Affinity_single-chain_pdb"
# Clinical parameters 

# Folder containing variant csvs 
# export clinical_data_folder_subs="folder containing clinical substitution csvs"
# export clinical_data_folder_indels="folder containing clinical indel csvs"

# Folders containing multiple sequence alignments and MSA weights for all clinical datasets
# export clinical_MSA_data_folder_subs="folder containing clinical MSA files for substitutions"
# export clinical_MSA_data_folder_indels="folder containing clinical MSA files for indels"

# Folder containing MSA weights for all clinical datasets
# export clinical_MSA_weights_folder_subs="/home/zliang/project/proteinsquare/data/MSA/a2m_weights"
# export clinical_MSA_weights_folder_indels="folder containing clinical MSA weights for indels"

# reference files for substitution and indel clinical variants 
# export clinical_reference_file_path_subs=../../reference_files/clinical_substitutions.csv
# export clinical_reference_file_path_indels=../../reference_files/clinical_indels.csv

# Folder where clinical benchmark fitness predictions for baseline models are saved
# export clinical_output_score_folder_subs="folder for clinical substitution scores"
# export clinical_output_score_folder_indels="folder for clinical indel scores"

# Folder containing EVE models for each clinical variant
# export clinical_EVE_model_folder="folder for clinical EVE models"

# Folder containing merged score files for each clinical variant
# export clinical_merged_score_folder_subs="folder for merged scores for clinical substitutions"
# export clinical_merged_score_folder_indels="folder for merged score for clinical indels"

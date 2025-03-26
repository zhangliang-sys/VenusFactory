import argparse
import numpy as np
from pathlib import Path
import torch
import torch.nn.functional as F
from tqdm import tqdm
import time
import pandas as pd
import os 
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from baselines.esm import esm
import esm.inverse_folding
from esm.inverse_folding.util import CoordBatchConverter

SCORE_NATIVE = False


def get_sequence_loss_batch(model, alphabet, coords_list, seq_list):
    device = next(model.parameters()).device
    batch_converter = CoordBatchConverter(alphabet)
    assert len(coords_list) == len(seq_list)
    batch = [(coords, None, seq) for coords, seq in zip(coords_list, seq_list)]
    coords, confidence, strs, tokens, padding_mask = batch_converter(batch, device=device)
    prev_output_tokens = tokens[:, :-1].to(device)
    target = tokens[:, 1:]
    target_padding_mask = (target == alphabet.padding_idx)
    logits, _ = model.forward(coords, padding_mask, confidence, prev_output_tokens)
    loss = F.cross_entropy(logits, target, reduction='none')
    losses = loss.cpu().detach().numpy()
    target_padding_masks = target_padding_mask.cpu().numpy()
    return losses, target_padding_masks

def score_sequence_batch(model, alphabet, coords_list, seq_list):
    losses, target_padding_masks = get_sequence_loss_batch(model, alphabet, coords_list, seq_list)
    print("debug: losses and target_padding_mask shapes: ", losses.shape, target_padding_masks.shape)
    ll_fullseqs_batch = -np.sum(losses * ~target_padding_masks, axis=1) / np.sum(~target_padding_masks, axis=1)
    return ll_fullseqs_batch


def score_singlechain_backbone_batch(model, alphabet, pdb_file, chain, mutation_file, output_filepath, batch_size=1,nogpu=False):
    if not nogpu:
        assert torch.cuda.is_available(), "Expected GPU. If you want to use CPU, you have to specify --nogpu every time."
        model = model.cuda()
        print("Transferred model to GPU")
    else:
        print(f"Running model on CPU: torch cuda is available={torch.cuda.is_available()} nogpu={nogpu}")

    start_time = time.perf_counter()
    coords, native_seq = esm.inverse_folding.util.load_coords(pdb_file, chain)
    print(f"Coords loaded in {time.perf_counter() - start_time} seconds")
    mut_df = pd.read_csv(mutation_file)
    seq_list = mut_df["mutated_sequence"].tolist()
    header_list = mut_df["mutant"].tolist()
    coords_list = [coords] * len(seq_list)

    print(f"Sequences loaded in {time.perf_counter() - start_time} seconds")

    start_scoring = time.perf_counter()
    
    with open(output_filepath, 'w') as fout:
        fout.write('mutant,esmif1_ll\n')
    for i in tqdm(range(0, len(seq_list), batch_size)):
        batch = seq_list[i:i+batch_size]
        coords_batch = coords_list[i:i+batch_size]
        ll_fullseq = score_sequence_batch(model, alphabet, coords_batch, batch)
        with open(output_filepath, 'a') as fout:
            for header, ll in zip(header_list[i:i+batch_size], ll_fullseq):
                fout.write(header + ',' + str(ll) + '\n')

    print(f"Scoring in {time.perf_counter() - start_scoring} seconds")
        
    print(f'Results saved to {output_filepath}')
    print(f"Total time: {time.perf_counter() - start_time}")

def score_multichain_backbone_batch(model, alphabet, pdb_file, target_chain, mutation_file, output_filepath, batch_size=1, nogpu=False):
    # GPU设置
    if torch.cuda.is_available() and not nogpu:
        model = model.cuda()
        print("Transferred model to GPU")
    
    start_time = time.perf_counter()
    
    # 加载结构和坐标
    structure = esm.inverse_folding.util.load_structure(pdb_file)
    try:
        coords, native_seqs = esm.inverse_folding.multichain_util.extract_coords_from_complex(structure)
    except KeyError as e:
        print(f"警告：发现非标准氨基酸残基。尝试将非标准氨基酸映射为标准氨基酸...")
        
        # 添加非标准氨基酸到标准氨基酸的映射
        from biotite.sequence.seqtypes import ProteinSequence
        custom_mappings = {
            'CGU': 'R',  # CGU (修饰的精氨酸) 映射到 R (精氨酸)
            'IAS': 'I',  # IAS (异亮氨酸变体) 映射到 I (异亮氨酸)
            'M3L': 'K',  # M3L (三甲基赖氨酸) 映射到 K (赖氨酸)
            # 可以根据需要添加更多映射
        }
        
        # 临时添加自定义映射到转换字典
        original_dict = ProteinSequence._dict_3to1.copy()
        ProteinSequence._dict_3to1.update(custom_mappings)
        
        try:
            coords, native_seqs = esm.inverse_folding.multichain_util.extract_coords_from_complex(structure)
        finally:
            # 恢复原始转换字典
            ProteinSequence._dict_3to1 = original_dict
    
    native_seq = native_seqs[target_chain]
    print(f'Native sequence for chain {target_chain} loaded from structure file:')
    print(native_seq)
    print(f'Structure loaded in {time.perf_counter() - start_time} seconds')

    # 加载突变序列
    mut_df = pd.read_csv(mutation_file)
    seq_list = mut_df["mutated_sequence"].tolist()
    header_list = mut_df["mutant"].tolist()
    
    start_scoring = time.perf_counter()
    
    # 写入结果
    with open(output_filepath, 'w') as fout:
        fout.write('mutant,esmif1_ll\n')
        
        # 批量处理序列
        for i in tqdm(range(0, len(seq_list), batch_size)):
            batch_seqs = seq_list[i:i+batch_size]
            batch_headers = header_list[i:i+batch_size]
            
            for seq, header in zip(batch_seqs, batch_headers):
                ll, _ = esm.inverse_folding.multichain_util.score_sequence_in_complex(
                    model, 
                    alphabet, 
                    coords, 
                    target_chain, 
                    seq
                )
                fout.write(f"{header},{ll}\n")

    print(f"Scoring completed in {time.perf_counter() - start_scoring} seconds")
    print(f'Results saved to {output_filepath}')

def main():
    parser = argparse.ArgumentParser(description='Score sequences based on a given structure.')
    parser.add_argument('--DMS_reference_file_path',type=str,help='path to DMS reference file')
    parser.add_argument('--DMS_data_folder',type=str,help="path to folder containing DMS data")
    parser.add_argument('--structure_folder',type=str,help='folder containing pdb files for each DMS')
    parser.add_argument('--DMS_index',type=int,help='index of DMS in DMS reference file')
    parser.add_argument('--model_location',type=str,help='path to model')
    parser.add_argument('--batch_size',type=int,default=1)
    parser.add_argument('--output_scores_folder',type=str,help='path to folder where scores will be saved')
    parser.add_argument('--chain', type=str,help='chain id for the chain of interest', default='A')
    parser.set_defaults(multichain_backbone=False)
    parser.add_argument('--multichain-backbone', action='store_true',help='use the backbones of all chains in the input for conditioning')
    parser.add_argument('--singlechain-backbone', dest='multichain_backbone',action='store_false',help='use the backbone of only target chain in the input for conditioning')
    parser.add_argument("--nogpu", action="store_true", help="Do not use GPU even if available")
    
    args = parser.parse_args()
    mapping_df = pd.read_csv(args.DMS_reference_file_path)
    DMS_id = mapping_df.iloc[args.DMS_index]['DMS_id']
    DMS_filename = mapping_df.iloc[args.DMS_index]['DMS_filename']
    output_filename = args.output_scores_folder + os.sep + DMS_id + ".csv"
    
    if not os.path.exists(args.output_scores_folder):
        os.makedirs(args.output_scores_folder)
    
    pdb_file = args.structure_folder + os.sep + mapping_df.iloc[args.DMS_index]['pdb_file']
    model, alphabet = esm.pretrained.load_model_and_alphabet(args.model_location)
    model = model.eval()
    
    mutation_filename = args.DMS_data_folder + os.sep + DMS_filename
    
    if args.multichain_backbone:
        score_multichain_backbone_batch(
            model,
            alphabet,
            pdb_file=pdb_file,
            target_chain=args.chain,
            mutation_file=mutation_filename,
            output_filepath=output_filename,
            batch_size=args.batch_size,
            nogpu=args.nogpu
        )
    else:
        score_singlechain_backbone_batch(
            model,
            alphabet,
            pdb_file=pdb_file,
            chain=args.chain,
            mutation_file=mutation_filename,
            output_filepath=output_filename,
            batch_size=args.batch_size,
            nogpu=args.nogpu
        )

if __name__ == '__main__':
    main()

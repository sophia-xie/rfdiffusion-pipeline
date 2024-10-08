#!/bin/bash

# Run RFdiffusion with fold conditioning.
# Binder scaffolds must first be created using make_scaffolds.sh. 

### REQUIRED POSITIONAL ARGUMENTS
run_name=$1
path_to_pdb=$(realpath $2)
hotspots=$3
num_structs=$4
output_dir=$(realpath $5) 
scaffold_dir=$(realpath $6)
##############################

set -eo pipefail

RFDIFFUSION_DIR=/hpf/tools/alma8/RFDiffusion/1.1.0/

# get path to pipeline directory
if [ -n "${SLURM_JOB_ID:-}" ]; then  # job
    batch_job=$(scontrol show job ${SLURM_JOB_ID} | grep BatchFlag | awk -F "BatchFlag=" '{print $2}' | awk '{print $1}')
    if [ "${batch_job}" = "1" ]; then  # batch job
        script_path=$(scontrol show job "$SLURM_JOB_ID" | awk -F= '/Command=/{print $2}')
    else  # interactive shell
        script_path=$(realpath "$0")
    fi
else
    script_path=$(realpath "$0")
fi

pipeline_dir=$(realpath "$(dirname ${script_path})/../")

echo PIPELINE_DIR $pipeline_dir
echo RUN_NAME $run_name
echo PDB_PATH $path_to_pdb
echo HOTSPOTS $hotspots
echo NUM_STRUCTS $num_structs
echo OUTPUT_DIR $output_dir
echo SCAFFOLD_DIR $scaffold_dir

echo
echo Loading module...

module load RFDiffusion/1.1.0

echo Activating conda...

eval "$(conda shell.bash hook)"
conda activate /hpf/tools/centos7/miniforge/3/envs/SE3nv

echo
echo Generating target scaffolds for fold conditioning...

$RFDIFFUSION_DIR/helper_scripts/make_secstruc_adj.py \
    --input_pdb $path_to_pdb \
    --out_dir "${output_dir}/target_scaffold/"

pdb_name=$(basename -- "$path_to_pdb")
pdb_name="${pdb_name%.*}"
echo
echo pdb_name $pdb_name

target_ss=${output_dir}/target_scaffold/${pdb_name}_ss.pt
target_adj=${output_dir}/target_scaffold/${pdb_name}_adj.pt
echo target_ss $target_ss
echo target_adj $target_adj
echo

echo
echo Running RFdiffusion...

$RFDIFFUSION_DIR/scripts/run_inference.py \
    scaffoldguided.target_path=$path_to_pdb \
    scaffoldguided.scaffoldguided=True \
    "ppi.hotspot_res=[$hotspots]" \
    scaffoldguided.target_pdb=True \
    scaffoldguided.target_ss=$target_ss \
    scaffoldguided.target_adj=$target_adj \
    scaffoldguided.scaffold_dir=$scaffold_dir \
    inference.num_designs=$num_structs \
    inference.output_prefix=$output_dir/rfdiffusion/$run_name \
    denoiser.noise_scale_ca=0 \
    denoiser.noise_scale_frame=0 \
    scaffoldguided.mask_loops=False

echo
echo Done.


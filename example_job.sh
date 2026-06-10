#!/bin/bash
#SBATCH --job-name=gromacs
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=2
#SBATCH --cpus-per-task=16
#SBATCH --gres=gpu:2
#SBATCH --time=1:00:00
#SBATCH --account=IsCd4_MYH9-RD
#SBATCH --partition=boost_usr_prod
#SBATCH --exclusive
#SBATCH --output=gmx.%j.out
#SBATCH --error=gmx.%j.err

set -euo pipefail

module purge
module load profile/lifesc
module load gromacs/2022.3--openmpi--4.1.4--gcc--11.3.0-cuda-11.8
module help gromacs/2022.3--openmpi--4.1.4--gcc--11.3.0-cuda-11.8

export OMP_NUM_THREADS=16

# Correct variable for GROMACS 2022 GPU direct communication
export GMX_ENABLE_DIRECT_GPU_COMM=true

# Optional speed setting. Test carefully before final production.
export GMX_FORCE_UPDATE_DEFAULT_GPU=true

aa=$(echo $CUDA_VISIBLE_DEVICES | sed "s/,//g")

echo "CUDA_VISIBLE_DEVICES = $CUDA_VISIBLE_DEVICES"
echo "GPU ID used by GROMACS = $aa"
echo "GROMACS version:"
gmx_mpi --version

MAXWARN=1

# Step 1: Prepare the Topology
gmx_mpi pdb2gmx -f step1_pdbreader.pdb -o processed.gro -p topol.top -i posre.itp \
  -ff charmm36-jul2022 -water tip3p -ignh

# Step 2: Define the Unit Cell
gmx_mpi editconf -f processed.gro -o newbox.gro -c -d 1.2 -bt cubic

# Step 3: Add Solvent
gmx_mpi solvate -cp newbox.gro -cs spc216.gro -o solv.gro -p topol.top

# Step 4: Add Ions
gmx_mpi grompp -f ions.mdp -c solv.gro -p topol.top -o ions.tpr -maxwarn ${MAXWARN} > LOG_GROMPP_IONS 2>&1

printf "SOL\n" | gmx_mpi genion \
  -s ions.tpr \
  -o solv_ions.gro \
  -p topol.top \
  -pname NA \
  -nname CL \
  -neutral \
  -conc 0.15

# Step 5: Energy Minimization
gmx_mpi grompp -f minim.mdp -c solv_ions.gro -p topol.top -o em.tpr -maxwarn ${MAXWARN} > LOG_GROMPP_EM 2>&1

srun gmx_mpi mdrun \
  -v \
  -deffnm em \
  -ntomp 16 \
  -pin off

# Step 6: NVT Equilibration
gmx_mpi grompp -f nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr -maxwarn ${MAXWARN} > LOG_GROMPP_NVT 2>&1

srun gmx_mpi mdrun \
  -deffnm nvt \
  -gpu_id $aa \
  -ntomp 16 \
  -nb gpu \
  -pme gpu \
  -bonded gpu \
  -pin off \
  -cpt 15

# Step 7: NPT Equilibration
gmx_mpi grompp -f npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr -maxwarn ${MAXWARN} > LOG_GROMPP_NPT 2>&1

srun gmx_mpi mdrun \
  -deffnm npt \
  -gpu_id $aa \
  -ntomp 16 \
  -nb gpu \
  -pme gpu \
  -bonded gpu \
  -pin off \
  -cpt 15

# Step 8: Production MD
gmx_mpi grompp -f md.mdp -c npt.gro -t npt.cpt -p topol.top -o md_0_1.tpr -maxwarn ${MAXWARN} > LOG_GROMPP_MD 2>&1

srun gmx_mpi mdrun \
  -deffnm md_0_1 \
  -gpu_id $aa \
  -ntomp 16 \
  -nb gpu \
  -pme gpu \
  -bonded gpu \
  -pin off \
  -cpt 15 > LOG_MDRUN_MD 2>&1
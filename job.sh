#!/bin/bash
#
# General GROMACS protein MD workflow for SLURM-based HPC systems.
#
# Adapted from:
# Justin A. Lemkul, "Lysozyme in Water", MDTutorials
# http://www.mdtutorials.com/gmx/lysozyme/
#
# Additional modifications:
# - SLURM HPC execution
# - GPU-accelerated NVT/NPT/production MD
# - restartable production MD using checkpoints
# - chunked execution using -maxh
# - optional simulation extension using gmx convert-tpr
#
# Required files in the same folder:
# protein.pdb
# ions.mdp
# minim.mdp
# nvt.mdp
# npt.mdp
# md.mdp
# charmm36-jul2022.ff/

#SBATCH --job-name=protein_md
#SBATCH -N 1
#SBATCH --ntasks-per-node=4          # 1 MPI rank per GPU
#SBATCH --cpus-per-task=8            # 4 ranks * 8 OMP threads = 32 CPUs
#SBATCH --gpus-per-task=1            # Slurm maps one GPU per MPI rank
#SBATCH --gres=gpu:4
#SBATCH --time=24:00:00              # 24 h chunk
#SBATCH --account=YOUR_PROJECT_ACCOUNT      # project/account name
#SBATCH --partition=YOUR_HPC_PARTITION      # partition/queue name
#SBATCH --exclusive
#SBATCH --hint=nomultithread
#SBATCH --output=gmx.%j.out
#SBATCH --error=gmx.%j.err

module purge
module load profile/lifesc
module load YOUR_GROMACS_MODULE
module help YOUR_GROMACS_MODULE

export OMP_NUM_THREADS=8
export GMX_ENABLE_DIRECT_GPU_COMM=1

DEFFNM=protein_md
MAXH=23.5

# Run setup/equilibration only once. If protein_md.tpr exists, skip directly to production continuation.
if [ ! -f ${DEFFNM}.tpr ]; then

# Step 1: Prepare the Topology
gmx_mpi pdb2gmx -f protein.pdb -o processed.gro -p topol.top -i posre.itp \
  -ff charmm36-jul2022 -water tip3p -ignh

# Step 2: Define the Unit Cell
gmx_mpi editconf -f processed.gro -o newbox.gro -c -d 1.2 -bt cubic

# Step 3: Add Solvent
gmx_mpi solvate -cp newbox.gro -cs spc216.gro -o solv.gro -p topol.top

# Step 4: Add Ions
gmx_mpi grompp -f ions.mdp -c solv.gro -p topol.top -o ions.tpr -maxwarn -1
printf "SOL\n" | gmx_mpi genion -s ions.tpr -o solv_ions.gro -p topol.top -pname NA -nname CL -neutral

# Step 5: Energy Minimization
gmx_mpi grompp -f minim.mdp -c solv_ions.gro -p topol.top -o em.tpr -maxwarn -1
srun gmx_mpi mdrun -v -deffnm em -ntomp 8 -pin on

# Step 6: NVT Equilibration
gmx_mpi grompp -f nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr -maxwarn -1
srun gmx_mpi mdrun -deffnm nvt -ntomp 8 -nb gpu -pme gpu -npme 1 -pin on

# Step 7: NPT Equilibration
gmx_mpi grompp -f npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr -maxwarn -1
srun gmx_mpi mdrun -deffnm npt -ntomp 8 -nb gpu -pme gpu -npme 1 -pin on

# Step 8a: Generate Production TPR
gmx_mpi grompp -f md.mdp -c npt.gro -t npt.cpt -p topol.top -o ${DEFFNM}.tpr > LOG_GROMPP 2>&1

fi

# Step 8b: Production MD, restartable chunk mode
if [ -f ${DEFFNM}.cpt ]; then
    echo "Continuing production MD from checkpoint ${DEFFNM}.cpt"
    srun gmx_mpi mdrun -deffnm ${DEFFNM} -cpi ${DEFFNM}.cpt -append -ntomp 8 -nb gpu -pme gpu -npme 1 -pin on -maxh ${MAXH} >> LOG_MDRUN 2>&1
else
    echo "Starting first production MD chunk from ${DEFFNM}.tpr"
    srun gmx_mpi mdrun -deffnm ${DEFFNM} -ntomp 8 -nb gpu -pme gpu -npme 1 -pin on -maxh ${MAXH} >> LOG_MDRUN 2>&1
fi


#extend simulation time later (remove # and run on hpc after the current simulation is fully finished. here -extend 100000 is 100000 ps for 100 ns, adjust for time to be extended)
#cp protein_md.tpr protein_md_200ns.tpr
#gmx_mpi convert-tpr -s protein_md_200ns.tpr -extend 100000 -o protein_md.tpr
#sbatch job.sh

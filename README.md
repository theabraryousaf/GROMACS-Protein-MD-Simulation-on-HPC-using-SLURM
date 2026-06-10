# GROMACS Protein MD on HPC using SLURM

Beginner-friendly template for running a protein molecular dynamics simulation using GROMACS on an HPC cluster with SLURM.

This workflow is adapted from:

Justin A. Lemkul, "Lysozyme in Water", MDTutorials  
http://www.mdtutorials.com/gmx/lysozyme/

Additional modifications were added for HPC/SLURM execution, GPU acceleration, checkpoint continuation, chunked walltime-limited runs, and simulation extension using `gmx convert-tpr`.

## Repository structure

```text
GROMACS-HPC-Protein-MD/
├── README.md
├── job.sh
├── protein.pdb
├── ions.mdp
├── minim.mdp
├── nvt.mdp
├── npt.mdp
├── md.mdp
├── charmm36-jul2022.ff/
└── .gitignore
```

## Required files

Upload these files/folders:

```text
job.sh
protein.pdb
ions.mdp
minim.mdp
nvt.mdp
npt.mdp
md.mdp
charmm36-jul2022.ff/
```

## Edit before running

In `job.sh`, replace:

```bash
#SBATCH --account=YOUR_PROJECT_ACCOUNT
#SBATCH --partition=YOUR_HPC_PARTITION
module load YOUR_GROMACS_MODULE
module help YOUR_GROMACS_MODULE
```

with the correct values for your HPC.

The script uses the local CHARMM36 force field folder:

```text
charmm36-jul2022.ff/
```

and calls it using:

```bash
-ff charmm36-jul2022
```

## Submit the job

```bash
sbatch job.sh
```

## Continue the simulation after a walltime chunk

The script uses:

```bash
-maxh 23.5
```

For a 24-hour SLURM job, this stops GROMACS safely before walltime. To continue, submit the same script again:

```bash
sbatch job.sh
```

It continues from:

```text
protein_md.cpt
```

and appends to the same output files.

## Check job status

```bash
squeue -u $USER
```

## Check progress

```bash
grep -A1 "Step           Time" protein_md.log | tail -1 | awk '{print "Completed ns = " $2/1000}'
```

## Check performance

```bash
grep "Performance:" protein_md.log | tail -1
```

## Extend a completed simulation

Do not run this while the simulation is still running.

Example: extend a completed 200 ns simulation by 100 ns.

```bash
cp protein_md.tpr protein_md_200ns.tpr
gmx_mpi convert-tpr -s protein_md_200ns.tpr -extend 100000 -o protein_md.tpr
sbatch job.sh
```

Here:

```text
100000 ps = 100 ns
```

## Important files not to delete

```text
protein_md.tpr
protein_md.cpt
protein_md.xtc
protein_md.edr
protein_md.log
```

## Notes

Energy minimization is run without GPU PME. GPU PME is used for NVT, NPT, and production MD.

Users should inspect all `grompp` warnings and validate equilibration before using production results.

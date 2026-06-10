# GROMACS Protein MD on HPC using SLURM

Beginner-friendly template for running a protein molecular dynamics simulation using **GROMACS** on an **HPC cluster with SLURM**.

This repository contains a complete workflow for:

1. Preparing a protein topology
2. Creating a simulation box
3. Adding water
4. Adding ions
5. Running energy minimization
6. Running NVT equilibration
7. Running NPT equilibration
8. Running production MD in restartable HPC chunks
9. Extending a completed simulation if more sampling is needed

The workflow is adapted from:

**Justin A. Lemkul, “Lysozyme in Water,” MDTutorials**  
http://www.mdtutorials.com/gmx/lysozyme/

Additional modifications were added for HPC/SLURM execution, GPU acceleration, checkpoint continuation, chunked walltime-limited runs, and simulation extension using `gmx convert-tpr`.

---

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
├── docs/
│   ├── leonardo_file_transfer_example.txt
│   └── leonardo_login_example.txt
└── .gitignore
```

---

## Files you need

Before running, place these files in the same directory:

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

### File descriptions

| File/folder | Purpose |
|---|---|
| `job.sh` | Main SLURM job script |
| `protein.pdb` | Input protein structure |
| `ions.mdp` | Parameters for ion preparation |
| `minim.mdp` | Energy minimization parameters |
| `nvt.mdp` | NVT equilibration parameters |
| `npt.mdp` | NPT equilibration parameters |
| `md.mdp` | Production MD parameters |
| `charmm36-jul2022.ff/` | CHARMM36 force field folder |

---

## Important beginner note

This repository is a **template**. You must edit the script for your own HPC system before running.

In `job.sh`, change:

```bash
#SBATCH --account=YOUR_PROJECT_ACCOUNT
#SBATCH --partition=YOUR_HPC_PARTITION
module load YOUR_GROMACS_MODULE
```

For example, your HPC may require a module name like:

```bash
module load gromacs/2022.3
```

or:

```bash
module load gromacs/2022.3-cuda
```

Ask your HPC support team or check your HPC documentation if you are unsure.

---

## Main user settings in `job.sh`

The most important editable variables are:

```bash
INPUT_STRUCTURE="protein.pdb"
DEFFNM="protein_md"
FF="charmm36-jul2022"
WATER="tip3p"
MAXH="23.5"
```

### Meaning

| Variable | Meaning |
|---|---|
| `INPUT_STRUCTURE` | Name of your input protein PDB file |
| `DEFFNM` | Base name for production output files |
| `FF` | Force field name |
| `WATER` | Water model |
| `MAXH` | Maximum GROMACS run time per job chunk in hours |

The script uses:

```bash
-ff charmm36-jul2022
```

This works when the folder:

```text
charmm36-jul2022.ff/
```

is present in the same working directory.

---

## How to submit the simulation

From the folder containing `job.sh`, run:

```bash
sbatch job.sh
```

---

## What the script does

The first submission performs:

```text
1. pdb2gmx
2. editconf
3. solvate
4. genion
5. energy minimization
6. NVT equilibration
7. NPT equilibration
8. production TPR generation
9. production MD
```

The script checks whether the production `.tpr` file already exists:

```bash
if [[ ! -f "${DEFFNM}.tpr" ]]; then
```

If `protein_md.tpr` already exists, the script skips setup/equilibration and continues production from checkpoint.

---

## Output files

Production MD produces files such as:

```text
protein_md.tpr
protein_md.cpt
protein_md.xtc
protein_md.edr
protein_md.log
```

Do not delete these files while the simulation is running or if you plan to continue/extend the simulation.

---

## Running in chunks

Many HPC systems have walltime limits. This script uses:

```bash
-maxh 23.5
```

For a 24-hour SLURM job, this tells GROMACS to stop safely before the walltime limit and write a checkpoint.

If the simulation stops before reaching the final time, submit the same script again:

```bash
sbatch job.sh
```

It will continue from:

```text
protein_md.cpt
```

using:

```bash
-cpi protein_md.cpt -append
```

---

## Check job status

```bash
squeue -u $USER
```

---

## Check the last 50 lines of job output

Replace `<JOBID>` with your SLURM job ID:

```bash
tail -50 gmx.<JOBID>.out
tail -50 gmx.<JOBID>.err
```

---

## Check simulation progress

```bash
grep -A1 "Step           Time" protein_md.log | tail -1 | awk '{print "Completed ns = " $2/1000}'
```

The time in the GROMACS log is in ps, so dividing by 1000 gives ns.

---

## Check performance

```bash
grep "Performance:" protein_md.log | tail -1
```

Example output:

```text
Performance: 75.794 ns/day
```

---

## How simulation length is controlled

The total simulation length is controlled by `dt` and `nsteps` in `md.mdp`.

Example:

```text
dt      = 0.002
nsteps  = 100000000
```

Calculation:

```text
100000000 × 0.002 ps = 200000 ps = 200 ns
```

So this gives a 200 ns production simulation.

---

## Extend a completed simulation

Do **not** extend while the simulation is still running.

Example: the simulation finished 200 ns and you want to add 100 ns more.

Since:

```text
100 ns = 100000 ps
```

Run:

```bash
cp protein_md.tpr protein_md_200ns.tpr
gmx_mpi convert-tpr -s protein_md_200ns.tpr -extend 100000 -o protein_md.tpr
sbatch job.sh
```

This changes the target length from 200 ns to 300 ns total.

The simulation continues from:

```text
protein_md.cpt
```

and appends to:

```text
protein_md.xtc
protein_md.edr
protein_md.log
```

---

## Important scientific notes

### 1. Always inspect `grompp` warnings

The script uses:

```bash
MAXWARN=0
```

This means warnings are not ignored by default. This is safer for general use.

Only increase `MAXWARN` after reading and understanding the warning.

### 2. Energy minimization does not use GPU PME

Energy minimization is run without:

```bash
-pme gpu
```

GPU PME is used only for NVT, NPT, and production MD in this template.

### 3. Validate equilibration

Before trusting production results, check:

- energy minimization convergence
- temperature stability during NVT
- pressure/density stability during NPT
- system geometry
- protein structure after equilibration

---

## Uploading to GitHub

Recommended files to upload:

```text
README.md
job.sh
protein.pdb
ions.mdp
minim.mdp
nvt.mdp
npt.mdp
md.mdp
charmm36-jul2022.ff/
docs/
.gitignore
```

Avoid uploading:

```text
*.xtc
*.trr
*.edr
*.cpt
*.tpr
*.log
```

These are large generated simulation files and are excluded by `.gitignore`.

---

## Acknowledgement

This workflow is adapted from the GROMACS tutorial:

Justin A. Lemkul, “Lysozyme in Water,” MDTutorials  
http://www.mdtutorials.com/gmx/lysozyme/

The present version adds a beginner-friendly SLURM/HPC workflow for GPU-accelerated, restartable, chunked GROMACS production simulations.

---

## Disclaimer

This repository is a teaching and workflow template. Users must validate all parameters, structures, protonation states, force field choices, box sizes, equilibration settings, and production settings for their own molecular system.

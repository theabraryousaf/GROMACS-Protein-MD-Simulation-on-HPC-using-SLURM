# GROMACS Protein MD on HPC using SLURM

This repository contains a beginner-friendly GROMACS molecular dynamics workflow for running protein simulations on an HPC cluster using SLURM. The workflow includes system preparation, solvation, ion addition, energy minimization, NVT equilibration, NPT equilibration, and restartable/chunked production MD.

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

### Update `md.mdp` for the simulation length you want

Before submitting `job.sh`, edit the production MD file:

```text
md.mdp
```

The total production simulation length is controlled by `nsteps` and `dt`:

```text
integrator              = md         ; leap-frog integrator
nsteps                  = 100000000  ; number of MD steps
dt                      = 0.002      ; time step in ps, here 0.002 ps = 2 fs
```

The total simulation time is:

```text
total simulation time = nsteps × dt
```

Example for 200 ns:

```text
100000000 × 0.002 ps = 200000 ps = 200 ns
```

Common examples when `dt = 0.002 ps`:

```text
nsteps = 50000000     ; 100 ns
nsteps = 100000000    ; 200 ns
nsteps = 250000000    ; 500 ns
nsteps = 500000000    ; 1000 ns = 1 us
```

Important: edit `md.mdp` before the first production `.tpr` file is generated. Once `protein_md.tpr` already exists, changing `md.mdp` alone will not change the running simulation length. To extend an already completed simulation, use `gmx_mpi convert-tpr` as described below.

### Download CHARMM36 force field folder

Download the CHARMM36 force field folder from the MacKerell Lab CHARMM force field page:

[Download CHARMM36 force field files for GROMACS](http://mackerell.umaryland.edu/charmm_ff.shtml#gromacs)

For this template, the expected folder name is:

```text
charmm36-jul2022.ff/
```

After downloading the `.tgz` file, extract it in the same directory as `job.sh`. Example:

```bash
tar -zxvf charmm36-jul2022.ff.tgz
```

Then confirm that this folder exists:

```bash
ls charmm36-jul2022.ff/
```

## Edit before running

In `job.sh`, replace:

```bash
#SBATCH --account=YOUR_PROJECT_ACCOUNT
#SBATCH --partition=YOUR_HPC_PARTITION
module load YOUR_GROMACS_MODULE
```

with the correct values for your HPC.

If your HPC requires an extra profile module, uncomment and edit this line in `job.sh`:

```bash
# module load profile/lifesc
```

The script uses the local CHARMM36 force field folder:

```text
charmm36-jul2022.ff/
```

and calls it using:

```bash
-ff charmm36-jul2022
```

## Upload files to HPC

After preparing the repository folder on your local computer, upload the complete folder to your HPC system.

### Option 1: upload with `rsync`

Run this command from your local computer terminal, not from inside the HPC:

```bash
rsync -avP GROMACS-HPC-Protein-MD/ USERNAME@HPC_HOST:/path/to/your/project/GROMACS-HPC-Protein-MD/
```

Replace:

```text
USERNAME                 your HPC username
HPC_HOST                 your HPC login or data-transfer host
/path/to/your/project/   your working/project directory on the HPC
```

Example format:

```bash
rsync -avP GROMACS-HPC-Protein-MD/ USERNAME@data.your-hpc.edu:/path/to/your/project/GROMACS-HPC-Protein-MD/
```

### Option 2: upload with `scp`

```bash
scp -r GROMACS-HPC-Protein-MD USERNAME@HPC_HOST:/path/to/your/project/
```

### Check uploaded files on HPC

Login to the HPC:

```bash
ssh USERNAME@HPC_LOGIN_NODE
```

Go to your simulation folder:

```bash
cd /path/to/your/project/GROMACS-HPC-Protein-MD
```

Check that all required files are present:

```bash
ls
```

You should see:

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

## Submit the job

From inside the simulation folder on the HPC, submit the SLURM job:

```bash
sbatch job.sh
```

Check that the job was submitted:

```bash
squeue -u $USER
```

Check the SLURM output and error files:

```bash
tail -50 gmx.<JOBID>.out
tail -50 gmx.<JOBID>.err
```

Replace `<JOBID>` with your actual SLURM job ID.

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

## Notes for beginners

Energy minimization is run without GPU PME. GPU PME is used for NVT, NPT, and production MD.

This template is for a standard protein-only system. Systems with ligands, cofactors, membranes, metal ions, modified residues, or nonstandard residues require extra topology/parameter files and additional checks.

The box distance, ion settings, force field, water model, and MDP parameters should be checked for each system. The default `-d 1.2` cubic box is a reasonable starting point for many globular proteins but may not be suitable for every protein.

This public template does not use `-maxwarn` by default. Users should inspect all `grompp` warnings and validate equilibration before using production results. GROMACS warnings should not be ignored unless the user understands the cause and knows it is safe.

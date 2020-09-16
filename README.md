# np-signal

Nanopore signal based processing pipelines (Fast5) :peacock:

## Setup

This prototype can be setup as follows:

```
git clone --recursive https://github.com/np-core/np-signal
```

It requires the container [`Signal`](https://github.com/np-core/containers) to be available in either `Docker` or as `Singularity` image file, for example as specified in the default deployment configuration file `configs/nextflow.config`. Models by default are found inside the container at `/models` and the default model configuration is `dna_r9.4.1_450bps_hac.cfg` with `Guppy v4.0.14` running on an `NVIDIA-Ubuntu16.04 CUDA 9.0 and CUDNN 7.0` instance which should work for `NIVIDIA` GPUs with drivers `> v384.81`.

## Help

```
nextflow run np-signal/main.nf --help true
```

```
=========================================
     N P - S I G N A L  v${version}
=========================================

Usage (offline):

The typical command for running the pipeline is as follows for file-wise signal processing:

    nextflow run np-signal/main.nf --config jcu -profile tesla --path fast5/ 

Pipeline config:

    Model configuration files can be found inside the container at: /models

    Resources can be configured hierarchically by first selecting a configuration file from
    ${baseDir}/configs with `--config <name>`

    Resource or execution profiles defined within the configuration files are selected with
    the native argument `-profile`

    --config                select a configuration from the configs subdirectory of the pipeline
    --container             path to container file or docker tag to provision pipeline
    -profile                select an resource and execution profile from the config file 


Input / output:

    --path                  the path to directory or a glob for Fast5 (as string)
    --archived              input files are expected to be tar gzipped files ending with .tar.gz or .tgz
    --outdir                the path to directory for result outputs

Guppy @ GPU configuration:

    --guppy_model               base guppy model configuration file for basecalling 
    --guppy_params              base guppy additional parameter configurations by user 
    --guppy_data                base guppy model data directory, inside container
    --gpu_devices               gpus to use, provide list of devices passed to Guppy 
    --gpu_forks                 parallel basecalling instances to launch on GPUs
    --runners_per_device        parallel basecalling runners on GPUs
    --chunks_per_runner         the number of signal chunks processed on each runner
    --chunk_size                the size of the signal chunks processed on the gpu runers
    --num_callers               the number of basecallers spread across the devices
    --cpu_threads_per_caller    the number of cpu threads per caller

Qcat demultiplexing configuration:

    --demultiplex          activate demultiplexing with Qcat
    --qcat_params          additional qcat parameters passed by the user 

=========================================
```

## Input

Single directory to pass to a single instance of `Guppy` for basecalling files in the directory (recursively) - can be `.tar` or `.tar.gz` if `--archived` flag is set:

```
nextflow run np-signal/main.nf --config jcu -profile tesla --path fast5_files/
```

```
nextflow run np-signal/main.nf --config jcu -profile tesla --path fast5.tar.gz --archived true
```

You can also pass settings to `guppy_params` for example to basecall the directory recursively:

```
nextflow run np-signal/main.nf --config jcu -profile tesla --path fast5_files/ --guppy_params "-r"
```

You can make use of multiple `gpu_devices` (but not multiple instances of Guppy):

```
nextflow run np-signal/main.nf --config jcu -profile tesla --path fast5_files/ --gpu_devices "cuda:0 cuda:1"
```

Aggregate of `Fast5` files to pass individually to Guppy callers using a glob in quotes to prevent list expansion (!) - can make use of `forks` (to allow multiple files called in parallel) and `gpu_devices`.

```
nextflow run np-signal/main.nf --config jcu -profile tesla --path "fast5_files/*.fast5"
```

```
nextflow run np-signal/main.nf --config jcu -profile tesla --path "fast5_files/*.fast5" --gpu_forks 2 --gpu_devices "cuda:0 cuda:1"
```

If you split a larger `Fast5` collection for example into `fast5/collection1/*.fast5` and `fast5/collection2/*.fast5` you can use a glob on the directory to utilize multiple instances (`forks`) of `Guppy` calling all files within the directories:

```
nextflow run np-signal/main.nf --config jcu -profile tesla --path "fast5/collection*" --gpu_forks 2 --gpu_devices "cuda:0 cuda:1"
```

## Output

By default the pipeline outputs to `$PWD/results`. Files in `results/guppy` are by identification (either file or directory) and summarized (by directory) or single (by file), including:

* `.telemetry` -  telemetry output log from `Guppy`
* `.summary` - Basecalled read summary file (`sequencing_summary.txt` from Guppy)
* `.fq` - Basecalled reads from `Guppy`

## Resource usage

Use the following parameters on the command line to specify GPU spread:

* `--gpu_forks` number of processes that can be run on all available GPUs at the same time - use this to replicate the same process across your available GPUs
* `--gpu_devices` pass one ("cuda:0") or multiple ("cuda:0 cuda:1") GPU devices passed to Guppy - use this to spread the resource demands across your available GPUs

Use a combination of both to run the optimal number of parallel signal processes over multiple GPUs.

Memory and CPU consumption is mainly determined by the following parameters for `Guppy`:

* `gpu_runners_per_device` [4]
* `chunks_size` [1024]
* `chunks_per_runner` [1024]
* `num_callers` [4]

Default parameter configurations uses around 7 GB memory on a single Tesla V100 with 4 CPU threads per Guppy caller.

# np-signal

Nanopore signal based processing pipelines (Fast5) :peacock:

```
nextflow run np-core/np-signal --help true
```

## Container

[`Signal`](https://github.com/np-core/containers) environments are available for `Docker` and `Singularity` containers, as for instance configured in the default configuration file [`configs/nextflow.config`](https://github.com/np-core/configs/blob/master/nextflow.config). You can specifify a `Docker` container tag or `Singularity` image file path from the command-line using the `--container` parameter, e.g. using the hosted `Docker` container (`np-core/signal`).

## Basecalling

`Guppy` model confgurations can be found inside the container at `/models`; the default model configuration is `dna_r9.4.1_450bps_hac.cfg` with `Guppy v4.0.14` running on an `NVIDIA-Ubuntu16.04 CUDA 9.0 and CUDNN 7.0` image, which should work for `NVIDIA` GPUs using drivers > `v384.81`.

## Usage

```
=========================================
     N P - S I G N A L  v${version}
=========================================

Usage (offline):

The typical command for running the pipeline is as follows on a single directory 
containing the Fast5 files for local GPU signal processing:

    nextflow run np-core/np-signal --config nextflow -profile gpu_docker --path fast5/ 

Pipeline config:

    Model configuration files can be found inside the container at: /models

    Resources can be configured hierarchically by first selecting a configuration file from
    ${baseDir}/configs with `--config <name>`

    Resource or execution profiles defined within the configuration files are selected with
    the native argument `-profile`

    --container             path to container file or docker tag to provision pipeline
    --config                select a configuration from the configs subdirectory of the pipeline
                              
                              <nextflow>  base configuration with docker or singularity profiles
                              <jcu>       base configuration for the zodiac cluster at JCU
                              <nectar>    base configuration for the nectar cluster at QCIF
                              
    -profile                select an resource and executor profile from the config file 
               
                              <docker> / <gpu_docker>  - expect container to be tag format
                              <singularity> / <gpu_singularity> - expect container to be path to image


Input / output:

    --path                  the path to directory or a glob for Fast5 (quoted string) ["$PWD"]
    --archived              input files are expected to be tar gzipped files ending with .tar.gz or .tgz [false]
    --outdir                the path to directory for result outputs ["$PWD/results"]

Guppy @ GPU configuration:

    --guppy_model               base guppy model configuration file for basecalling ["dna_r9.4.1_450bps_hac.cfg"]
    --guppy_params              base guppy additional parameter configurations by user [""]
    --guppy_data                base guppy model data directory, inside container ["/models"]
    --gpu_devices               gpus to use, provide list of devices passed to Guppy  ["cuda:0"]
    --gpu_forks                 parallel basecalling instances to launch on GPUs [1]
    --runners_per_device        parallel basecalling runners on GPUs [4]
    --chunks_per_runner         the number of signal chunks processed on each runner [1024]
    --chunk_size                the size of the signal chunks processed on the gpu runers [1024]
    --num_callers               the number of basecallers spread across the devices [4]
    --cpu_threads_per_caller    the number of cpu threads per caller [4]

Qcat demultiplexing configuration:

    --demultiplex          activate demultiplexing with Qcat [false]
    --qcat_params          additional qcat parameters passed by the user ["--trim"]

=========================================
```

## Input

Examples are using a manual configuration and proffile for the JCU GPU server Tesla (`configs/jcu.config`)

Single directory to pass to a single instance of `Guppy` for basecalling files in the directory (recursively):

```
nextflow run np-core/np-signal --config jcu -profile tesla --path fast5_files/
```

Can be `.tar` or `.tar.gz` if `--archived` flag is set:

```
nextflow run np-core/np-signal--config jcu -profile tesla --path fast5.tar.gz --archived true
```

You can also pass settings to `--guppy_params` for example to basecall the directory recursively:

```
nextflow run np-core/np-signal--config jcu -profile tesla --path fast5_files/ --guppy_params "-r"
```

You can make use of multiple `--gpu_devices` for basecalling a single directory with `Guppy`:

```
nextflow run np-core/np-signal --config jcu -profile tesla --path fast5_files/ --gpu_devices "cuda:0 cuda:1"
```

Aggregate of `Fast5` files to pass to individual `Guppy` callers using a glob (in quotes to prevent list expansion):

```
nextflow run np-core/np-signal--config jcu -profile tesla --path "fast5_files/*.fast5"
```

In this case you can make use of `--gpu_forks` (to allow multiple files called in parallel processes) and `gpu_devices`:

```
nextflow run np-core/np-signal --config jcu -profile tesla --path "fast5_files/*.fast5" --gpu_forks 2 --gpu_devices "cuda:0 cuda:1"
```

If you split a larger `Fast5` collection into for example `fast5/collection1/*.fast5` and `fast5/collection2/*.fast5` you can use a glob on the directory to utilize multiple instances (`--gpu_forks`) of `Guppy` for each directory calling all files within:

```
nextflow run np-core/np-signal --config jcu -profile tesla --path "fast5/collection*" --gpu_forks 2 --gpu_devices "cuda:0 cuda:1"
```

## Output

By default the pipeline outputs to `$PWD/results`. Files in `results/guppy` are prefixed by the input directory or file base name:

* `{id}.telemetry` -  telemetry output log from `Guppy`
* `{id}.summary` - Basecalled read summary file of all reads (`sequencing_summary.txt`)
* `{id}.fq` - Basecalled and concatenated reads from `Guppy`

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

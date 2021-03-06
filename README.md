# np-signal

Nanopore signal based processing pipelines (Fast5) :peacock:

```
nextflow run np-core/np-signal --help true
```

## Basecalling

`Guppy` model configuration files can be found inside the container at `/guppy_models` or `/rerio_models`; the directory can be set using the `--guppy_params` argument, for example: `--guppy_data "/rerio_models"`. Default model configuration is `dna_r9.4.1_450bps_hac.cfg` on `Guppy v4.0.14`.

`Bonito` model configuration is curently locked for the publicly available model `dna_r9.4.1` and will be expanded when the basecaller is developed further. If you would like to use custom `Bonito` models, please let us know.

## Usage

```
=========================================
     N P - S I G N A L  v${version}
=========================================

Usage (offline):

The typical command for running the pipeline is as follows on a single directory 
containing the Fast5 files for local GPU signal processing:

    nextflow run np-core/np-signal --config nextflow -profile gpu_docker --path fast5/ 

Basecalling configuration:

    Model configuration files can be found inside the container at: /guppy_models or /rerio_models

Input / output configuration:

    --path                  the path to directory or a glob for Fast5 (quoted string) ["$PWD"]
    --batch_size            batch input files or directories for basecalling on a single instance of the caller [0]
    --archived              input files are expected to be tar gzipped files ending with .tar.gz or .tgz [false]
    --outdir                the path to directory for result outputs ["$PWD/results"]

Guppy configuration:

    --basecaller                select a basecaller, one of: guppy, bonito [guppy]
    --bonito_model              bonito basecalling model, currently only DNA R9.4.1 ["dna_r9.4.1"]
    --bonito_device             bonito gpu device to use for basecalling [cuda]
    --bonito_params             bonito additional basecaller configuration [""]
    --guppy_model               base guppy model configuration file for basecalling ["dna_r9.4.1_450bps_hac.cfg"]
    --guppy_params              base guppy additional parameter configurations by user [""]
    --guppy_data                base guppy model data directory, inside container ["/guppy_models"]
    --gpu_devices               gpus to use, provide list of devices passed to Guppy  ["cuda:0"]
    --gpu_forks                 parallel basecalling instances to launch on GPUs [1]
    --runners_per_device        parallel basecalling runners on GPUs [4]
    --chunks_per_runner         the number of signal chunks processed on each runner [1024]
    --chunk_size                the size of the signal chunks processed on the gpu runers [1024]
    --num_callers               the number of basecallers spread across the devices [4]
    --cpu_threads_per_caller    the number of cpu threads per caller [4]

Qcat configuration:

    --demultiplex          activate demultiplexing with Qcat [false]
    --qcat_params          additional qcat parameters passed by the user ["--trim"]

=========================================
```

## Configuration


For resource configuration selection, please see: [`np-core/configs`](https://github.com/np-core/configs)

Containers:

* Docker tag: `np-core/signal:latest`
* Singularity image: `signal-latest.sif`

System configs:

* **Default configuration**: `nextflow`
* James Cook University cluster: `jcu`
* NECTAR cloud: `nectar`

Resource configs (default config):

* Local server: `process`

Profile configs (default config):

* `docker` / `docker_gpu`
* `singularity` / `singularity_gpu`

## Input

Examples are using a manual configuration file and profile for the JCU GPU server Tesla (`configs/jcu.config`)

### Single Directory

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
nextflow run np-core/np-signal --config jcu -profile tesla --path fast5_files/ --guppy_params "-r"
```

You can make use of multiple `--gpu_devices` for basecalling a single directory with `Guppy`:

```
nextflow run np-core/np-signal --config jcu -profile tesla --path fast5_files/ --gpu_devices "cuda:0 cuda:1"
```

### Multiple Directories

If you split a larger `Fast5` collection into for example `fast5/collection1/*.fast5` and `fast5/collection2/*.fast5` you can use a glob on the directory to utilize multiple instances (`--gpu_forks`) of `Guppy` for each directory calling all files within:

```
nextflow run np-core/np-signal --config jcu -profile tesla --path "fast5/collection*" --gpu_forks 2 --gpu_devices "cuda:0 cuda:1"
```

### Multiple Files

Aggregate of `Fast5` files to pass to individual `Guppy` callers using a glob (in quotes to prevent list expansion):

```
nextflow run np-core/np-signal --config jcu -profile tesla --path "fast5_files/*.fast5"
```

It is recommended to batch `Fast5` files to pass them to a single (paralell) instance of the basecaller for more efficient processing:

```
nextflow run np-core/np-signal --config jcu -profile tesla --path "fast5_files/*.fast5" --batch_size 30
```

In this case you can make use of `--gpu_forks` (to allow multiple files called in parallel processes) and `gpu_devices`:

```
nextflow run np-core/np-signal --config jcu -profile tesla --path "fast5_files/*.fast5" --gpu_forks 2 --gpu_devices "cuda:0 cuda:1"
```

## Output

By default the pipeline outputs to `$PWD/results`. Files in `results/guppy` or `results/bonito` are prefixed by the input directory or file base name (`{id}`):

* `{id}/` - symlink to basecalling directory using `Guppy`
* `{id}.telemetry` -  copy of telemetry output log from `Guppy`
* `{id}.summary` - copy of basecalled read summary file from `Guppy` or `Bonito`
* `{id}.fq` - copy of basecalled reads from `Guppy` or `Bonito`

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

Default parameter configurations uses around 7 GB memory on a single Tesla V100 with 4 CPU threads per `Guppy` caller, in the default configuration `Bonito` takes up around 2.5 GB memory on a GTX1080-Ti.

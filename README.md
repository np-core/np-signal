# np-signal

Nanopore signal based processing pipelines (Fast5) :peacock:

## Setup

This prototype can be setup as follows:

```
git clone https://github.com/np-core/np-signal
```

It requires the container [`Signal`](https://github.com/np-core/containers) to be available in either `Docker` or as `Singularity` image file as specified in the deployment configuration file [`configs/nextflow.config`]

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

### Resource usage

Use the following parameters on the command line to specify GPU spread:

* `forks` number of processes that can be run on all available GPUs at the same time - use this to replicate the same process across your available GPUs [1]
* `gpu_devices` pass one ("cuda:0") or multiple ("cuda:0 cuda:1") GPU devices passed to Guppy - use this to spread the resource demands across your available GPUs ["cuda:0"]


Use a combination of both to run the optimal number of parallel signal processes over multiple GPUs.

Memory and CPU consumption is mainly determined by the following parameters for `Guppy`:

* `gpu_runners_per_device` [4]
* `chunks_size` [1024]
* `chunks_per_runner` [1024]
* `num_callers` [4]

Default parameter configurations uses around 7 GB memory on a single Tesla V100 with 4 CPU threads per Guppy caller.

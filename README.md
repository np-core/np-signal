# np-signal

Nanopore signal based processing pipelines (Fast5) :peacock:

## Input

Single directory to pass to `Guppy` for basecalling all files (non-recursive) - can be `.tar` or `.tar.gz` if `archived` flag is set:

```
nextflow run main.nf --config jcu -profile tesla --path fast5_files/
```

```
nextflow run main.nf --config jcu -profile tesla --path fast5.tar.gz --archived true
```

Can make use of multiple `gpu_devices`:

```
nextflow run main.nf --config jcu -profile tesla --path fast5_files/ --gpu_devices "cuda:0 cuda:1"
```

Aggregate of `Fast5` files to pass individually to Guppy callers using a glob in quotes to prevent list expansion (!) - can make use of `forks` (to allow multiple files called in parallel) and `gpu_devices`.

```
nextflow run main.nf --config jcu -profile tesla --path "fast5_files/*.fast5"
```

```
nextflow run main.nf --config jcu -profile tesla --path "fast5_files/*.fast5" --forks 2 --gpu_devices "cuda:0 cuda:1"
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

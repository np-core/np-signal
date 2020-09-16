# np-signal

Nanopore signal based processing pipelines (Fast5) :peacock:

## Overview

...

### Resource usage

Memory and CPU consumption is mainly determined by the following parameters for `Guppy`:

* `gpu_runners_per_device` [4]
* `chunks_size` [1024]
* `chunks_per_runner` [1024]
* `num_callers` [4]

Default parameter configurations uses around 7 GB memory on a single Tesla V100 with 4 CPU threads per Guppy caller.

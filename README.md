# np-signal

Nanopore signal based processing pipelines (Fast5) :peacock:

## Overview

...

### Resource usage

Memory consumption is mainly determined by the following parameters for `Guppy`:

* `gpu_runners_per_device`
* `chunks_size`
* `chunks_per_runner`

Configuration in `configs/jcu.config` uses around 6.5 GB memory on a single Tesla V100.

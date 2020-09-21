#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
==============================================================================================================================
                                        N P - S I G N A L   P I P E L I N E
==============================================================================================================================

 Nanopore signal processing pipeline (Fast5)

 Documentation: https://github.com/np-core/np-signal

 Original development by Queensland Genomics, Australian Institute of Tropical Health 
 and Medicince, The Peter Doherty Intitute for Infection and Immunity

Developers:

    Eike Steinig  @esteinig  < @EikeSteinig >

Pipeline part of the NanoPath core framework:

    https://github.com/np-core

NanoPath distributed pipeline framework Netflow:

    https://github.com/np-core/netflow

For interactive dashboard operation and report generation:

    https://github.com/np-core/nanopath

----------------------------------------------------------------------------------------
*/

import java.nio.file.Paths

nextflow.enable.dsl=2

params.path = "$PWD"
params.archived = false
params.outdir = "$PWD/results"

params.guppy_model = "dna_r9.4.1_450bps_hac.cfg"
params.guppy_params = ""
params.guppy_data = "/guppy_models" 
params.gpu_devices = "cuda:0"
params.runners_per_device = 4
params.chunks_per_runner = 1024
params.chunk_size = 1024
params.cpu_threads_per_caller = 4
params.num_callers = 4

params.batch_size = 0 // batch the input files or directories to process on a single basecaller process

params.demultiplex = false
params.qcat_params = "--trim"

// Workflow version

version = '0.1.3'

def helpMessage() {

    log.info"""
    =========================================
     N P - S I G N A L  v${version}
    =========================================

    Usage (offline):

    The typical command for running the pipeline is as follows on a single directory
    containing the Fast5 files for local GPU signal processing:

        nextflow run np-core/np-signal --config nextflow -profile gpu_docker --path fast5/

    Deployment and resource configuration:

        Model configuration files can be found inside the container at: /models

        Resources can be configured hierarchically by first selecting a configuration file from
        ${baseDir}/configs with `--config` and a specific resource configuration with `--resource config`

        Specific process execution profiles defined within the configuration files are selected with
        the native argument `-profile`

        --container             path to container file or docker tag to provision pipeline

                                  <np-core/signal>    Example for tag of latest Docker image
                                  <$HOME/signal.sif>  Example for path to singularity image file

        --config                select a configuration from the configs subdirectory of the pipeline

                                  <nextflow>  base configuration with docker or singularity profiles
                                  <jcu>       base configuration for the zodiac cluster at JCU
                                  <nectar>    base configuration for the nectar cluster at QCIF

        --resource_config       select a resource configuration nested within the selected configuration

                                  <process>   base configuration of processes for compute server resources

        -profile                select a system executor profile from the config file - default:

                                  <docker> / <gpu_docker>  - expect container to be tag format
                                  <singularity> / <gpu_singularity> - expect container to be path to image

    Input / output configuration:

        --path                  the path to directory of fast5 files to pass to Guppy (single folder) or a glob for Fast5 [${params.path}]
        --archived              input files are expected to be tar gzipped files ending with .tar.gz or .tgz [${params.archived}]
        --outdir                the path to directory for result outputs [${params.outdir}]

    GPU basecalling configuration:

        --guppy_model               base guppy model configuration file for basecalling [${params.guppy_model}]
        --guppy_params              base guppy additional parameter configurations by user ["${params.guppy_params}"]
        --guppy_data                base guppy model data directory, inside container ["${params.guppy_data}"]
        --gpu_devices               gpus to use, provide list of devices passed to the -x flag in Guppy ["${params.gpu_devices}"]
        --gpu_forks                 parallel basecalling instances to launch on GPUs [${params.gpu_forks}]
        --runners_per_device        parallel basecalling runners on gpus [${params.runners_per_device}]
        --chunks_per_runner         the number of signal chunks processed on each runner [${params.chunks_per_runner}]
        --chunk_size                the size of the signal chunks processed on the gpu runers[${params.chunk_size}]
        --num_callers               the number of basecallers spread across the devices [${params.num_callers}]
        --cpu_threads_per_caller    the number of cpu threads per caller [${params.num_callers}]

    Qcat demultiplexing configuration:

        --demultiplex          activate demultiplexing with Qcat [${params.demultiplex}]
        --qcat_params          additional qcat parameters passed by the user ["${params.qcat_params}"]

    =========================================

    """.stripIndent()
}


params.help = false
if (params.help){
    helpMessage()
    exit 0
}

def check_file(file) {
    
    path = Paths.get(file)

    if (path.exists()){
        log.info"""
        Detected input file: $file
        """
    } else {
        log.info"""
        Failed to detect input file: $file
        """
        exit 0
    }
}

// Input file checks, if none detected exit with error:


// Helper functions

def get_fast5(glob, batch_size){
    paths = channel.fromPath(glob, type: 'any')
    batch = 0
    if (batch_size > 1) { // outputs batch id, file list, which the basecall process takes into consideration
        println params.batch_size
        println paths
        batches = paths.collate( params.batch_size ).map { files -> batch += 1; tuple("batch_${batch}", files) }
        batches | view
        return batches
    } else {
        return paths.map { path -> tuple(path.baseName, path) }
    } // outputs id, file or directory path, which the basecall process takes into consideration
}

include { Guppy } from './modules/guppy'
include { Qcat } from './modules/qcat'

workflow basecall_fast5 {
    take:
        fast5 // id, fast5
    main:
        guppy_results = Guppy(fast5)
        fastq = guppy_results[0]
        if (params.demultiplex){
            fastq = Qcat(fastq)
        }
    emit:
        fastq
        guppy_results[1]
}

workflow {
    get_fast5(params.path, params.batch_size) | basecall_fast5
}
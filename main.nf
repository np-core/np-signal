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

params.basecaller = "guppy"
params.bonito_model = "dna_r9.4.1"
params.bonito_device = "cuda:0"
params.bonito_params = ""
params.guppy_model = "dna_r9.4.1_450bps_hac.cfg"
params.guppy_params = ""
params.guppy_data = "/guppy_models" 
params.guppy_devices = "cuda:0"
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
    containing Fast5 files for local GPU basecalling with Docker:

        nextflow run np-core/np-signal --config nextflow -profile gpu_docker --path fast5/

    Deployment and resource configuration:

        Resources can be configured hierarchically by first selecting a configuration file from
        presets with `--config` and resource presets with `--resource_config`

        Specific process execution profiles defined within the configuration files are selected with
        the native argument `-profile`

        For more information see: https://github.com/np-core/config 

    Input / output configuration:

        --path                  the path to directory of fast5 files to pass to Guppy (single folder) or a glob for Fast5 [${params.path}]
        --batch_size            batch input files or directories for basecalling on a single instance of the caller [${params.batch_size}]
        --outdir                the path to directory for result outputs [${params.outdir}]
        
    GPU basecalling configuration:

        --basecaller                select a basecaller, one of: guppy, bonito [${params.basecaller}]
        --bonito_model              bonito basecalling model, currently only DNA R9.4.1 [${params.bonito_model}]
        --bonito_device             bonito gpu device to use for basecalling [${params.bonito_device}]
        --bonito_params             bonito additional basecaller configuration [${params.bonito_params}]
        --guppy_model               guppy model configuration file for basecalling [${params.guppy_model}]
        --guppy_params              guppy additional parameter configurations by user ["${params.guppy_params}"]
        --guppy_data                guppy model data directory, inside container ["${params.guppy_data}"]
        --guppy_devices             gpus to use, provide list of devices passed to the -x flag in Guppy ["${params.guppy_devices}"]
        --gpu_forks                 parallel basecalling instances to launch on GPUs [${params.gpu_forks}]
        --runners_per_device        parallel basecalling runners on gpus [${params.runners_per_device}]
        --chunks_per_runner         the number of signal chunks processed on each runner [${params.chunks_per_runner}]
        --chunk_size                the size of the signal chunks processed on guppy runners [${params.chunk_size}]
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

// Input file checks, if none detected exit with error:

def get_fast5(glob){
    return channel.fromPath(glob, type: 'any') | map { path -> tuple(path.simpleName, path) }  // simple name for multiple . extensions
}
def get_fast5_files(glob){
    return paths = channel.fromPath(glob, type: 'file')
}


include { Bonito } from './modules/bonito'
include { BonitoBatch } from './modules/bonito'
include { Guppy } from './modules/guppy'
include { GuppyBatch } from './modules/guppy'
include { Qcat } from './modules/qcat'

workflow basecall {
    take:
        fast5 // id, fast5 [any]
    main:
        if (params.basecaller == "guppy"){
            fastq = Guppy(fast5)
        } else {
            fastq = Bonito(fast5)
        }
        if (params.demultiplex){
            Qcat(fastq[0])
        }
    emit:
        fastq[0]
        fastq[1]
}

workflow basecall_batch {
    take:
        batch // batch id, fast5 [list of files]
    main:
        if (params.basecaller == "guppy"){
            fastq = GuppyBatch(batch)
        } else {
            fastq = BonitoBatch(fast5)
        }
        if (params.demultiplex){
            Qcat(fastq[0])
        }
    emit:
        fastq[0]
        fastq[1]
}

workflow {
    if (params.batch_size > 0){
        batch = 0
        get_fast5_files(params.path) | collate( params.batch_size ) | map { batch += 1; tuple("batch_${batch}", it) } | basecall_batch
    } else {
        get_fast5(params.path) | basecall
    }
}
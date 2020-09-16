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

import java.nio.file.Paths;

nextflow.enable.dsl=2;

// nextflow config is loaded before compilation

params.path = "$PWD"  // input file directory containing ONT (.fq, .fastq) or Illumina (.fq.gz, .fastq.gz, PE) reads
params.recursive = false // recursive file search
params.archived = false // do the fiels with .tar.gz and require decompression and dearchiving?
params.outdir = "$PWD/results" // result output directory, must be full path!

params.guppy_model = "dna_r9.4.1_450bps_hac.cfg"
params.guppy_params = ""
params.guppy_data = "/models" // inside container
params.gpu_devices = "cuda:0"
params.runners_per_device = 4
params.chunks_per_runner = 1024
params.chunk_size = 1024
params.cpu_threads_per_caller = 4
params.num_callers = 4

params.demultiplex = false
params.qcat_params = "--trim"

// Workflow version

version = '0.1.1'

def helpMessage() {

    log.info"""
    =========================================
             N P - S I G N A L  v${version}
    =========================================

    Usage (offline):

    The typical command for running the pipeline is as follows for file-wise signal processing:

        nextflow run main.nf --config jcu --path fast5/ --recursive true

    Pipeline config:

        Model configuration files can be found inside the container at: /models

        Resources can be configured hierarchically by first selecting a configuration file from
        ${baseDir}/configs with `--config <name>`

        Resource or execution profiles defined within the configuration files are selected with
        the native argument `-profile`

        --config                select a configuration from the configs subdirectory of the pipeline [${params.config}]
        -profile                select an resource and execution profile from the config file [$workflow.profile]


    Input / output:

        --path                  the path to directory of fast5 files to pass to Guppy (single folder) or a glob for Fast5 [${params.path}]
        --recursive             activate recrusive file search for input directory [${params.recursive}]
        --archived              input files are expected to be tar gzipped files ending with .tar.gz or .tgz [${params.archived}]
        --outdir                the path to directory for result outputs [${params.outdir}]

    Guppy @ GPU configuration:

        --guppy_model          base guppy model configuration file for basecalling [${params.guppy_model}]
        --guppy_params         base guppy additional parameter configurations by user ["${params.guppy_params}"]
        --gpu_devices              gpus to use, provide list of devices passed to the -x flag in Guppy ["${params.gpu_devices}"]
        --runners_per_device   parameter to control parallel basecalling runners on gpus, fine-tune for memory usage [${params.runners_per_device}]
        --chunks_per_runner    parameter to control the number of signal chunks processed on each runner, fine-tune to control memory usage [${params.chunks_per_runner}]
        --chunk_size           parameter to control the size of the signal chunks processed on the gpu runers, fine-tune to control memory usage [${params.chunk_size}]
        --num_callers          parameter to control the number of basecallers spread across the devices, coarse control over memory usage [${params.num_callers}]

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

def get_fast5(glob){
    return channel.fromPath(glob) | map { file -> tuple(file.baseName, file) }
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
    get_fast5(params.path) | basecall_fast5
}
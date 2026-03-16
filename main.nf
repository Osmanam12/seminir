#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/sem
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/sem
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SEM  } from './workflows/sem'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_sem_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_sem_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_SEM {

    take:
    samplesheet // channel: samplesheet read in from --input

    main:

    //
    // WORKFLOW: Run pipeline
    //
    SEM (
        samplesheet
    )
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input
    )

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_SEM (
        PIPELINE_INITIALISATION.out.samplesheet
    )
    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.outdir,
        params.monochrome_logs,
    )
    // Run FastQC
    ch_multiqc_files = channel.empty()
    FASTQC(ch_samplesheet)
    // FastQC output files
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{ it[1] })

    // Run TrimGalore!
    TRIMGALORE(ch_samplesheet)
    // Adapter-trimmed FASTQ files, FastQC files and logfiles
    ch_trimmed_reads = TRIMGALORE.out.reads
    ch_multiqc_files = ch_multiqc_files.mix(TRIMGALORE.out.zip.collect{ it[1] })
    ch_multiqc_files = ch_multiqc_files.mix(TRIMGALORE.out.log.collect{ it[1] })

    // Run STAR
    ch_star_index = channel.value(file(params.star_index, checkIfExists: true))
    ch_gtf = channel.value(file(params.gtf, checkIfExists: true))
    STAR_ALIGN(
    ch_trimmed_reads,
    ch_star_index.map { [ [:], it ] },
    ch_gtf.map { [ [:], it ] },
    false)
    // STAR output files
    ch_multiqc_files = ch_multiqc_files.mix(STAR_ALIGN.out.log_final.collect{ it[1] })

    // Run SALMON quantification
    ch_salmon_index = channel.value(file(params.salmon_index, checkIfExists: true))
    ch_transcriptome = channel.value(file(params.transcriptome, checkIfExists: true))
    SALMON_QUANT(
    ch_trimmed_reads,
    ch_salmon_index,
    ch_gtf,
    ch_transcriptome,
    false,
    false
    )
    // SALMON output files
    ch_multiqc_files = ch_multiqc_files.mix(SALMON_QUANT.out.results.collect{ it[1] })

    // Run MultiQC
    MULTIQC(
    ch_multiqc_files.collect(),
    [], [], [], [], []
    )

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

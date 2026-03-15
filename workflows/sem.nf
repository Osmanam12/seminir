/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SEM {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    main:

    ch_versions = Channel.empty()

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'sem_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

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

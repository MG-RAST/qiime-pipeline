cwlVersion: v1.0
class: Workflow

inputs:
    raw_data:
        type: Directory
        doc: "Directory containing raw data"
    barcodes_file:
        type: File
        doc: "File containing barcodes"
    barcode_sequence:
        type: string
        doc: "Column name for barcodes in the mapping file"
    mapping_file:
        type: File
        doc: "Mapping file"
    gg_13_8_99_515_806_nb_classifier:
        type: File
        doc: "Pre-trained classifier for taxonomy assignment"

outputs:
    classifier:
        type: File
        outputSource: download_classifier/classifier
    core_metrics_results:
        type: Directory
        outputSource: core_metrics_phylogenetic/core_metrics_results
    faith_pd_group_significance:
        type: File
        outputSource: alpha_group_significance_faith_pd/faith_pd_group_significance
    shannon_group_significance:
        type: File
        outputSource: alpha_group_significance_shannon/shannon_group_significance
    evenness_group_significance:
        type: File
        outputSource: alpha_group_significance_evenness/evenness_group_significance
    alpha_rarefaction_results:
        type: Directory
        outputSource: alpha_rarefaction/alpha_rarefaction_results
    unweighted_unifrac_body_site_significance:
        type: File
        outputSource: beta_group_significance/unweighted_unifrac_body_site_significance
    alignment:
        type: File
        outputSource: align_to_tree_mafft_fasttree/alignment
    masked_alignment:
        type: File
        outputSource: align_to_tree_mafft_fasttree/masked_alignment
    unrooted_tree:
        type: File
        outputSource: align_to_tree_mafft_fasttree/unrooted_tree
    rooted_tree:
        type: File
        outputSource: align_to_tree_mafft_fasttree/rooted_tree
    rep_seqs:
        type: File
        outputSource: tabulate_seqs/rep_seqs
    taxonomy:
        type: File
        outputSource: classify_sklearn/taxonomy
    taxonomy_visualization:
        type: File
        outputSource: metadata_tabulate/taxonomy_visualization
    taxa_bar_plots:
        type: File
        outputSource: taxa_barplot/taxa_bar_plots
    table_visualization:
        type: File
        outputSource: feature_table_summarize/table_visualization
    paired_end_sequences:
        type: File
        outputSource: tools_import/paired_end_sequences
    demux_full:
        type: File
        outputSource: demux_emp_paired/demux_full
    error_correction_details:
        type: File
        outputSource: demux_emp_paired/error_correction_details
    demux_full_visualization:
        type: File
        outputSource: demux_summarize/demux_full_visualization
    demux_full_export:
        type: Directory
        outputSource: tools_export/demux_full_export
    representative_sequences:
        type: File
        outputSource: dada2_denoise_paired/representative_sequences
    table:
        type: File
        outputSource: dada2_denoise_paired/table
    denoising_stats:
        type: File
        outputSource: dada2_denoise_paired/denoising_stats
    table_dada2_visualization:
        type: File
        outputSource: feature_table_summarize_dada2/table_dada2_visualization
    rep_seqs_dada2_visualization:
        type: File
        outputSource: feature_table_tabulate_seqs/rep_seqs_dada2_visualization
    stats_dada2_visualization:
        type: File
        outputSource: metadata_tabulate_stats/stats_dada2_visualization

steps:
    download_classifier:
        run: CommandLineTool
        in: []
        out: [classifier]
        baseCommand: wget
        arguments: [
            "https://data.qiime2.org/classifiers/sklearn-1.4.2/greengenes/gg-13-8-99-515-806-nb-classifier.qza",
            "-O",
            "/path/to/output/gg-13-8-99-515-806-nb-classifier.qza"
        ]
    core_metrics_phylogenetic:
        run: CommandLineTool
        in: [
            phylogeny: rooted_tree,
            table: table_dada2,
            metadata: mapping_file
        ]
        out: [core_metrics_results]
        baseCommand: qiime diversity core-metrics-phylogenetic
        arguments: [
            "--p-sampling-depth", "500",
            "--output-dir", "/path/to/output/core-metrics-results"
        ]
    alpha_group_significance_faith_pd:
        run: CommandLineTool
        in: [
            alpha_diversity: core_metrics_results/faith_pd_vector,
            metadata: mapping_file
        ]
        out: [faith_pd_group_significance]
        baseCommand: qiime diversity alpha-group-significance
        arguments: [
            "--o-visualization", "/path/to/output/core-metrics-results/faith-pd-group-significance.qzv"
        ]
    alpha_group_significance_shannon:
        run: CommandLineTool
        in: [
            alpha_diversity: core_metrics_results/shannon_vector,
            metadata: mapping_file
        ]
        out: [shannon_group_significance]
        baseCommand: qiime diversity alpha-group-significance
        arguments: [
            "--o-visualization", "/path/to/output/core-metrics-results/shannon-group-significance.qzv"
        ]
    alpha_group_significance_evenness:
        run: CommandLineTool
        in: [
            alpha_diversity: core_metrics_results/evenness_vector,
            metadata: mapping_file
        ]
        out: [evenness_group_significance]
        baseCommand: qiime diversity alpha-group-significance
        arguments: [
            "--o-visualization", "/path/to/output/core-metrics-results/evenness-group-significance.qzv"
        ]
    alpha_rarefaction:
        run: CommandLineTool
        in: [
            table: table_dada2,
            phylogeny: rooted_tree
        ]
        out: [alpha_rarefaction_results]
        baseCommand: qiime diversity alpha-rarefaction
        arguments: [
            "--p-max-depth", "10000",
            "--p-steps", "100",
            "--output-dir", "/path/to/output/alpha-rarefaction-results"
        ]
    beta_group_significance:
        run: CommandLineTool
        in: [
            distance_matrix: core_metrics_results/unweighted_unifrac_distance_matrix,
            metadata: mapping_file
        ]
        out: [unweighted_unifrac_body_site_significance]
        baseCommand: qiime diversity beta-group-significance
        arguments: [
            "--m-metadata-column", "BodySite",
            "--o-visualization", "/path/to/output/core-metrics-results/unweighted-unifrac-body-site-significance.qzv",
            "--p-pairwise"
        ]
    align_to_tree_mafft_fasttree:
        run: CommandLineTool
        in: [sequences: rep_seqs_dada2]
        out: [
            alignment,
            masked_alignment,
            unrooted_tree,
            rooted_tree
        ]
        baseCommand: qiime phylogeny align-to-tree-mafft-fasttree
    tabulate_seqs:
        run: CommandLineTool
        in: [data: rep_seqs_dada2]
        out: [rep_seqs]
        baseCommand: qiime feature-table tabulate-seqs
        arguments: [
            "--o-visualization", "/path/to/output/rep-seqs.qzv"
        ]
    classify_sklearn:
        run: CommandLineTool
        in: [
            classifier: gg_13_8_99_515_806_nb_classifier,
            reads: rep_seqs_dada2
        ]
        out: [taxonomy]
        baseCommand: qiime feature-classifier classify-sklearn
    metadata_tabulate:
        run: CommandLineTool
        in: [input_file: taxonomy]
        out: [taxonomy_visualization]
        baseCommand: qiime metadata tabulate
        arguments: [
            "--o-visualization", "/path/to/output/taxonomy.qzv"
        ]
    taxa_barplot:
        run: CommandLineTool
        in: [
            table: table_dada2,
            taxonomy: taxonomy,
            metadata: mapping_file
        ]
        out: [taxa_bar_plots]
        baseCommand: qiime taxa barplot
        arguments: [
            "--o-visualization", "/path/to/output/taxa-bar-plots.qzv"
        ]
    feature_table_summarize:
        run: CommandLineTool
        in: [
            table: table_dada2,
            metadata: mapping_file
        ]
        out: [table_visualization]
        baseCommand: qiime feature-table summarize
        arguments: [
            "--o-visualization", "/path/to/output/table.qzv"
        ]
    tools_import:
        run: CommandLineTool
        in: [input_path: raw_data]
        out: [paired_end_sequences]
        baseCommand: qiime tools import
        arguments: [
            "--type", "EMPPairedEndSequences",
            "--output-path", "/path/to/output/paired-end-sequences.qza"
        ]
    demux_emp_paired:
        run: CommandLineTool
        in: [
            barcodes_file: barcodes_file,
            barcodes_column: barcode_sequence,
            seqs: paired_end_sequences
        ]
        out: [
            demux_full,
            error_correction_details
        ]
        baseCommand: qiime demux emp-paired
        arguments: [
            "--p-rev-comp-mapping-barcodes",
            "--p-rev-comp-barcodes",
            "--o-per-sample-sequences", "/path/to/output/demux-full.qza",
            "--o-error-correction-details", "/path/to/output/demux-details.qza"
        ]
    demux_summarize:
        run: CommandLineTool
        in: [data: demux_full]
        out: [demux_full_visualization]
        baseCommand: qiime demux summarize
        arguments: [
            "--o-visualization", "/path/to/output/demux-full.qzv"
        ]
    tools_export:
        run: CommandLineTool
        in: [input_path: demux_full_visualization]
        out: [demux_full_export]
        baseCommand: qiime tools export
        arguments: [
            "--output-path", "/path/to/output/demux-full"
        ]
    dada2_denoise_paired:
        run: CommandLineTool
        in: [demultiplexed_seqs: demux_full]
        out: [
            representative_sequences,
            table,
            denoising_stats
        ]
        baseCommand: qiime dada2 denoise-paired
        arguments: [
            "--p-trim-left-f", "0",
            "--p-trim-left-r", "0",
            "--p-trunc-len-f", "150",
            "--p-trunc-len-r", "150",
            "--o-representative-sequences", "/path/to/output/rep-seqs-dada2.qza",
            "--o-table", "/path/to/output/table-dada2.qza",
            "--o-denoising-stats", "/path/to/output/stats-dada2.qza"
        ]
    feature_table_summarize_dada2:
        run: CommandLineTool
        in: [
            table: table_dada2,
            metadata: mapping_file
        ]
        out: [table_dada2_visualization]
        baseCommand: qiime feature-table summarize
        arguments: [
            "--o-visualization", "/path/to/output/table-dada2.qzv"
        ]
    feature_table_tabulate_seqs:
        run: CommandLineTool
        in: [data: rep_seqs_dada2]
        out: [rep_seqs_dada2_visualization]
        baseCommand: qiime feature-table tabulate-seqs
        arguments: [
            "--o-visualization", "/path/to/output/rep-seqs-dada2.qzv"
        ]
    metadata_tabulate_stats:
        run: CommandLineTool
        in: [input_file: stats_dada2]
        out: [stats_dada2_visualization]
        baseCommand: qiime metadata tabulate
        arguments: [
            "--o-visualization", "/path/to/output/stats-dada2.qzv"
        ]
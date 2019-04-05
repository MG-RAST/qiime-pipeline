#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow

label: fasta2taxa-plot

doc: |
    Input is a fasta file with n>1 samples, with sample id as sequence identifier prefix, and a sample id file.
    The workflow calls open otus and assigns taxa using greengenes. The output are taxa plots. 

requirements:
  ResourceRequirement:
    coresMax: 1
    ramMin: 1024  # just a default, could be lowered
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  MultipleInputFeatureRequirement: {}
  SchemaDefRequirement:
    types:
      - type: enum
        name: level-type
        symbols:
          - Domain
          - Phylum
          - Class
          - Order
          - Family
          - Genus
          - Species
     
hints:
 SoftwareRequirement:
   packages:
     qiime:
       specs: [ "https://identifiers.org/rrid/RRID:SCR_008249" ]
       version: [ "1.9.1" ]



inputs:
    sample-mapping:
        type: File
    min-observations-per-otu:
        type: int?
    min-observations-per-sample:
        type: int?    
    summarize-for-taxonomic-levels:
        type: 
            type: record
            fields:
                numeric: int[]
                labels: level-type[]
    reads:
        type:
            type: record
            fields:
                forward: File
                reverse: File?
                index: File?

    taxonomy-file:
        type: File
    reference-sequences-fasta:
        type: File    

outputs: 

    validated-mapping-file:
        doc: mapping file validated with validate_mapping_file.py
        type: File
        outputSource: validate-mapping/corrected

    split-libraries:
        doc: output of split_libraries_fastq.py, demultiplex and quality filter (at Phred >= Q20)
        type: Directory
        outputSource: [ samples-to-fasta/demultiplexed ]         
          
    taxa-summary-plots:
        type: Directory
        outputSource: [ plot-taxa-summary/results]

    aplha-diversity-results:
        type: File
        outputSource: alpha-diversity/alpha 
       
    beta-diversity-results:
        type: Directory
        outputSource: beta-diversity/results    
    
    error-logs:  
        type: File[]
        doc: Error logs for each step, collected by default and can be empty.
        outputSource: [ 
                join-reads/stderr , 
                cluster/stderr , 
                taxonomy/stderr , 
                otu-table/stderr , 
                sort-table/stderr , 
                filter-otus/stderr , 
                summarize-taxa/stderr , 
                plot-taxa-summary/stderr , 
                alpha-diversity/stderr ,
                beta-diversity/stderr
                 ]  
    results:
        type: 
            type: array
            items:
                - File
                - Directory
        outputSource: [ 
            # validate-mapping/corrected ,
            join-reads/joined ,
            join-reads/index ,
            # samples-to-fasta/fasta ,
            # samples-to-fasta/log ,
            cluster/results , 
            taxonomy/id2taxonomy ,
            taxonomy/results ,
            otu-table/table ,
            sort-table/table ,
            filter-otus/table ,
            summarize-taxa/results ,
            # alpha-diversity/alpha ,
            # beta-diversity/results
            ]              


steps:
    validate-mapping:
        label:
        run: ../../Tools/qiime/validate_mapping_file.cwl
        in:
            mapping: sample-mapping
        out: [stderr , corrected ]
    

    join-reads:
        label: join paired ends
        run: ../../Tools/qiime/join_paired_ends.cwl
        in: 
            forward: 
                source: reads
                valueFrom: $(self.forward)
            reverse:
                source: reads
                valueFrom: $(self.reverse)
            index:
                source: reads
                valueFrom: $(self.index)
        out: [ joined , index , stderr ]

    samples-to-fasta:
        label: map sample ids and create fasta
        run: ../../Tools/qiime/split_libraries_fastq.cwl
        in:
            reads: 
                source: join-reads/joined
                valueFrom: ${ return [ self ]; }
            index: 
                source: join-reads/index
                valueFrom: ${ return [ self ]; }
            mapping: validate-mapping/corrected
        out: [ demultiplexed , fasta , log ]        
    cluster:
        label: pick de novo otus
        run: ../../Tools/qiime/pick_de_novo_otus.cwl
        in:
            fasta: samples-to-fasta/fasta
        out: [ results , uclust , representative_set , stderr]
    taxonomy:
        label: assign taxonomy
        run: ../../Tools/qiime/assign_taxonomy.cwl
        in:
            fasta: 
                source: cluster/representative_set
                valueFrom: $(self.fasta)
            id_to_taxonomy:
                source: taxonomy-file
            reference_sequences:
                source: reference-sequences-fasta   
        out: [stderr, results , id2taxonomy]
    otu-table:
        label: make out table
        run: ../../Tools/qiime/make_otu_table.cwl
        in:
            otu-mapping: 
                source: cluster/uclust
                valueFrom: $(self.otus)
            taxonomy-assignment:   taxonomy/id2taxonomy
        out: [ stderr , table ]
    sort-table:
        label: sort otu table by samples
        run: ../../Tools/qiime/sort_otu_table.cwl
        in: 
            otu-biom-table: otu-table/table
            sorted-sample-ids: validate-mapping/corrected
        out: [stderr, table]        

    filter-otus:
        label: remove singletons
        run: ../../Tools/qiime/filter_otus_from_otu_table.cwl
        in:
            otu-biom-table: sort-table/table
            min_observation_count:
                source: min-observations-per-otu
                default: 2
        out: [stderr , table ]

    filter-samples:
        label: remove samples with low coverage
        run: ../../Tools/qiime/filter_samples_from_otu_table.cwl
        in:
            otu-biom-table: filter-otus/table
            min_observation_count:
                source: min-observations-per-sample
                default: 100
        out: [stderr , table ]                

    summarize-taxa:
        label: list taxonomic levels
        run: ../../Tools/qiime/summarize_taxa.cwl
        in:
            otu-table: filter-samples/table
            taxonomic-level:
                source: summarize-for-taxonomic-levels
                valueFrom: $(self.numeric) 
        out: [ stderr , results , biom , txt ]  

    alpha-diversity:
        label: alpha diversity
        run: ../../Tools/qiime/alpha_diversity.cwl
        in: 
            otu-table: filter-samples/table
            method:
                default: [ chao1 , PD_whole_tree , shannon , observed_otus ]
            tree: 
                source: cluster/representative_set
                valueFrom: $(self.tree)
        out: [ stderr , alpha ]

    beta-diversity:
        label: beta diversity
        run: ../../Tools/qiime/beta_diversity_through_plots.cwl
        in: 
            otu-table: filter-samples/table
            mapping: validate-mapping/corrected
            tree:
                source: cluster/representative_set
                valueFrom: $(self.tree) 
        out: [ stderr , beta , results ]

    plot-taxa-summary:    
        label: plot summaries
        run: ../../Tools/qiime/plot_taxa_summary.cwl
        in:
            taxa-counts-files: 
                source: summarize-taxa/txt
                valueFrom:  |
                    ${ 
                        self.forEach( element => {
                                                    var res = element.location.match(/_L(\d+)/);
                                                    element.pos = res[1]
                                    } );
                        return self.sort(function(a,b){ return a.pos - b.pos } )
                    }
            labels:
                source: summarize-for-taxonomic-levels
                valueFrom: $(self.labels)
        out: [ stderr , results ]


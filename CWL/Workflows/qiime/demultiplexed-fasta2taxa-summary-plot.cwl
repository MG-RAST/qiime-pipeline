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
    samples-fna:
        type: File
    sample-mapping:
        type: File
    min-observations-per-otu:
        type: int?
    summarize-for-taxonomic-levels:
        type: 
            -   'null'
            -   type: record
                fields:
                    numeric: int[]
                    labels: level-type[]
                        
            # -   type: record
            #     fields:
            #         numeric: int[]
            #         levels:
            #             type:
            #                 type: array
            #                 items:
            #                     type: enum
            #                     symbols:
            #                         - Domain
            #                         - Phylum
            #                         - Class
            #                         - Order
            #                         - Family
            #                         - Genus
            #                         - Species


outputs: 
    results:
        type: File[]?
        outputSource: [ taxonomy/id2taxonomy , filter-otus/table ]
    plots:
        type: Directory
        outputSource: [ plot/results]    
    errors:
        type: File[]
        outputSource: [ cluster/stderr , taxonomy/stderr , otu-table/stderr , sort-table/stderr , filter-otus/stderr , summarize_taxa/stderr , plot/stderr ]        

steps:
    cluster:
        label: pick open otus
        run: ../../Tools/qiime/pick_de_novo_otus.cwl
        in:
            fasta: samples-fna
        out: [ uclust , representative_set , stderr]
    taxonomy:
        label: assign taxonomy
        run: ../../Tools/qiime/assign_taxonomy.cwl
        in:
            fasta: 
                source: cluster/representative_set
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
            sorted-sample-ids: sample-mapping
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

    summarize_taxa:
        label: list taxonomic levels
        run: ../../Tools/qiime/summarize_taxa.cwl
        in:
            otu-table: filter-otus/table
            taxonomic-level:
                source: summarize-for-taxonomic-levels
                default: [ 2,3,4,5,6,7 ]
                valueFrom: $(self.numeric) 
        out: [ stderr , biom , txt ]  

    plot:
        label: plot summaries
        run: ../../Tools/qiime/plot_taxa_summary.cwl
        in:
            taxa-counts-files: summarize_taxa/txt
            labels:
                source: summarize-for-taxonomic-levels
                valueFrom: $(self.labels)
        out: [ stderr , results ]


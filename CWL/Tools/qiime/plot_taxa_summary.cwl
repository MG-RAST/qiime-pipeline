#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
requirements:
  ResourceRequirement:
    coresMax: 1
    ramMin: 1024  # just a default, could be lowered
  InlineJavascriptRequirement: {}
     
hints:
 SoftwareRequirement:
   packages:
     qiime:
       specs: [ "https://identifiers.org/rrid/RRID:SCR_008249" ]
       version: [ "1.9.1" ]



baseCommand: plot_taxa_summary.py
# -i /summarize_taxa_output/L2.txt,summarize_taxa_output/L3.txt,summarize_taxa_output/L4.txt,summarize_taxa_output/L5.txt,summarize_taxa_output/L6.txt,summarize_taxa_output/L7.txt
# -o /plot_taxa_summary_output/
# -l Phylum,Class,Order,Family,Genus,Species






inputs:
  taxa-counts-files:
   type: File[]
   doc: summarized taxa
   inputBinding:
     prefix: --counts_fname
     itemSeparator: ","
  label:
    type: 
      - 'null'
      - type: enum
        symbols:
          - Domain
          - Phylum
          - Class
          - Order
          - Family
          - Genus
          - Species

    default: 'null'
    doc: |
      Comma-separated list of taxonomic levels (e.g.
      Phylum,Class,Order)  [default=none]
    inputBinding:
      prefix: --level
      itemSeparator: ","
  report-absolute-abundance:
    type: boolean
    default: true 
    inputBinding:
      prefix: --absolute_abundance     
  output:
    type: string
    default: ./results
    inputBinding:
      prefix: --dir_path
      
  


outputs:
  results:
    type: Directory
    outputBinding:
      glob: $(inputs.output)
  biom:
    type: File[]?
    outputBinding:
      glob: $(inputs.output)/*.biom
  txt:
    type:
      type: array
      items: 
        - File
        - 'null'
    outputBinding:
      glob: $(inputs.output)/*.txt          


  
  
$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/docs/schema_org_rdfa.html

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "n/a"

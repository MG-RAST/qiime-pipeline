#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
requirements:
  ResourceRequirement:
    coresMax: 1
    ramMin: 1024  # just a default, could be lowered
  InlineJavascriptRequirement: {}
     
hints:
  DockerRequirement: 
    dockerPull: mgrast/qiime:1.0.20180919
  SoftwareRequirement:
    packages:
      qiime:
        specs: [ "https://identifiers.org/rrid/RRID:SCR_008249" ]
        version: [ "1.9.1" ]


stderr: summarize_taxa.error
stdout: summarize_taxa.out

baseCommand: summarize_taxa.py
# -i /filter_otus_from_otu_table_output/seqs_otu_table_gg_ w_taxonomy_sorted.biom
# -o /summarize_taxa_output/
# -L 2,3,4,5,6,7
# -a





inputs:
  otu-table:
   type: File
   doc: Input OTU table filepath
   inputBinding:
     prefix: --otu_table_fp
  taxonomic-level:
    type: int[]
    default: [ 2,3,4,5,6,7 ]
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
    default: ./summarize_taxa
    inputBinding:
      prefix: --output_dir
      
  


outputs:
  results:
    type: Directory
    outputBinding:
      glob: $(inputs.output)
  stderr:
    type: stderr
  stdout: 
    type: stdout  
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

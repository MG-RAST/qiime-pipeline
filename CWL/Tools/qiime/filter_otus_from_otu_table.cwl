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


stderr: filter_otus_from_otu_table.error
stdout: filter_otus_from_otu_table.out

baseCommand: filter_otus_from_otu_table.py
# -i /sort_otu_table_output/otu_table_gg_from_biom_w_taxonomy_sorted.biom
# -o /filter_otus_from_otu_table_output/seqs_otu_table_gg_w_taxonomy_sorted.biom
# -n 2





inputs:
  otu-biom-table:
   type: File
   doc: Input OTU table filepath in BIOM format
   inputBinding:
     prefix: --input_fp
  min_observation_count:
    type: int
    default: 0
    inputBinding:
      prefix: --min_count
  output:
    type: string
    default: otu-biom-table-sorted
    inputBinding:
      prefix: --output_fp
  


outputs:
  stderr:
    type: stderr
  stdout:
    type: stdout  
  table:
    type: File
    outputBinding:
      glob: $(inputs.output)
 

  
  
$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/docs/schema_org_rdfa.html

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "n/a"

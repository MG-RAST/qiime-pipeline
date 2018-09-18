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


stderr: sort_otu_table.error
stdout: sort_otu_table.out

baseCommand: sort_otu_table.py
# -i / convert_biom_output_biom/otu_table_gg_from_biom_w_taxonomy.biom
# -o /sort_otu_table_output/otu_table_gg_from_biom_w_taxonomy_sorted.biom
# -l /sample_list_sorted.txt




inputs:
  otu-biom-table:
   type: File
   doc: Input OTU table filepath in BIOM format
   inputBinding:
     prefix: --input_otu_table
  sorted-sample-ids:
    type: File
    inputBinding:
      prefix: --sorted_sample_ids_fp    
  output:
    type: string
    default: otu-table-sorted.biom
    inputBinding:
      prefix: --output
  


outputs:
  stdout:
    type: stdout
  stderr:
    type: stderr
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

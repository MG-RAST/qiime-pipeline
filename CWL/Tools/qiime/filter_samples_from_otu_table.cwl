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


stderr: filter_samples_from_otu_table.error
stdout: filter_samples_from_otu_table.out

baseCommand: filter_samples_from_otu_table.py
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
    default: 1000
    inputBinding:
      prefix: --min_count
  output:
    type: string
    default: otu-table-filtered-samples.biom
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
 - https://schema.org/version/latest/schema.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "n/a"

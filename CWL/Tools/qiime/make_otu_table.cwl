#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
requirements:
  ResourceRequirement:
    coresMax: 1
    ramMin: 1024  # just a default, could be lowered
hints:
 SoftwareRequirement:
   packages:
     qiime:
       specs: [ "https://identifiers.org/rrid/RRID:SCR_008249" ]
       version: [ "1.9.1" ]



baseCommand: make_otu_table.py



inputs:
  otu-mapping:
   type: File
   doc: fasta file
   inputBinding:
     prefix: --otu_map_fp
  taxonomy-assignment:
    type: File?
    inputBinding:
      prefix: --taxonomy



arguments:
  - valueFrom: otu_table.biom
    prefix: --output_biom_fp




outputs:
  table:
    type: File
    outputBinding:
      glob: otu_table.biom
 

  
  
$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/docs/schema_org_rdfa.html

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "n/a"

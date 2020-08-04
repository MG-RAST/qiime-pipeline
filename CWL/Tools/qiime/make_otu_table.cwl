#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
requirements:
  ResourceRequirement:
    coresMax: 1
    ramMin: 1024  # just a default, could be lowered

hints:
  DockerRequirement: 
    dockerPull: mgrast/qiime:1.0.20180919
  SoftwareRequirement:
    packages:
      qiime:
        specs: [ "https://identifiers.org/rrid/RRID:SCR_008249" ]
        version: [ "1.9.1" ]

stderr: make_otu_table.error
stdout: make_otu_table.out

baseCommand: make_otu_table.py



inputs:
  otu-mapping:
   type: File
   doc: cluster ID to sequence IDs mapping, two column 
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
  stdout:
    type: stdout
  stderr:
    type: stderr  
  table:
    type: File
    outputBinding:
      glob: otu_table.biom
 


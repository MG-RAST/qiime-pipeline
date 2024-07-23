#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

requirements:
  ResourceRequirement:
    coresMax: 1
    ramMin: 4096  # just a default, could be lowered

hints:
  DockerRequirement: 
    dockerPull: mgrast/qiime:1.0
  SoftwareRequirement:
    packages:
      qiime:
        specs: [ "https://identifiers.org/rrid/RRID:SCR_008249" ]
        version: [ "1.9.1" ]

stderr: pick_closed_reference_otus.error
stdout: pick_closed_reference_otus.out

baseCommand: pick_closed_reference_otus.py


inputs:
  fasta:
    type: File
    doc: fasta file
    inputBinding:
      prefix: --input_fp
 
  reference_database:
    type: File?
    doc: reference sequence file, default is  qiime_default_reference/gg_13_8_otus/rep_set/97_otus.fasta
    inputBinding:
      prefix: --reference_fp  

  taxonomy_map:
    type: File?
    doc: taxonomy map text, default is qiime_default_reference/gg_13_8_otus/taxonomy/97_otu_taxonomy.txt
    inputBinding:
        prefix: --taxonomy_fp    

arguments:
 - valueFrom: otus_closed
   prefix: --output_dir
 - --force
 - --parallel  

outputs:
  stdout: 
    type: stdout
  stderr:
    type: stderr  
  results:
    type: Directory
    outputBinding: 
      glob: otus_closed
    
  
  

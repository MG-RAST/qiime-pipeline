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

stderr: pick_open_reference_otus.error
stdout: pick_open_reference_otus.out

baseCommand: pick_open_reference_otus.py


inputs:
  fasta:
    type: File
    doc: fasta file
    inputBinding:
      prefix: --input_fps
  method:
    type: string
    doc: otu picking method , usearch61 or uclust
    default: uclust
    inputBinding:
      prefix: --otu_picking_method  
  reference_database:
    type: File?
    doc: reference sequence file, default is  qiime_default_reference/gg_13_8_otus/rep_set/97_otus.fasta
    inputBinding:
      prefix: --reference_fp  

arguments:
 - valueFrom: otus
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
      glob: otus
  representative_set:
    type: 
      type: record
      fields:
        tree: 
          type: File
          outputBinding:
            glob: otus/rep_set.tre
        fasta:
          type: File
          outputBinding:
            glob: otus/rep_set.fna
  uclust:   
    type:
      type: record
      name: uclust
      fields:
        taxonomy:
          type: File?
          outputBinding:
            glob: otus/uclust_assigned_taxonomy/*rep_set_tax_assignments.txt
        # cluster:
        #   type: File?
        #   outputBinding:
        #     glob: otus/uclust_picked_otus/*clusters.uc
        # otus:
        #   type: File?
        #   outputBinding:
        #     glob: otus/uclust_picked_otus/*_otus.txt          
  
  

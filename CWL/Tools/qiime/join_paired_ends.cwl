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
        
stderr: join_paired_ends.error
stdout: join_paired_ends.out

inputs:
  forward:
   type: File
   inputBinding:
     prefix: -f
  reverse:
    type: File
    inputBinding:
      prefix: -r
  index:
    type: File
    inputBinding:
      prefix: -b     

baseCommand: join_paired_ends.py

arguments:
 - valueFrom: joined
   prefix: -o

outputs:
  stderr:
    type: stderr
  stdout:
    type: stdout
  unjoined:
    type: File[]
    outputBinding: { glob: "joined/fastqjoin.un*.fastq" }   
  joined:
    type: File
    outputBinding: { glob: "joined/fastqjoin.join.fastq" }
  index: 
    type: File?
    outputBinding: { glob: "joined/fastqjoin.join_barcodes.fastq" }  
  results:
    type: File[]
    outputBinding: { glob: "joined/*.fastq" }
  


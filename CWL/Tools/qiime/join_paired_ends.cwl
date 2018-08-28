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

inputs:
  forward:
   type: File
   inputBinding:
     prefix: -f
  reverse:
    type: File
    inputBinding:
      prefix: -r

baseCommand: join_paired_ends.py

arguments:
 - valueFrom: $(runtime.tmpdir)
   prefix: -o

outputs:
  merged:
    type: File
    outputBinding: { glob: $(runtime.tmpdir)/fastqjoin.join.fastq }
  

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "n/a"

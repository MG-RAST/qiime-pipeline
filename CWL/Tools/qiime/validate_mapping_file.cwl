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

stderr: validate_mapping_file.error
stdout: validate_mapping_file.out

inputs:
  mapping:
   type: File
   inputBinding:
     prefix: -m

baseCommand: validate_mapping_file.py 

arguments:
    - valueFrom: mapping
      prefix: -o

outputs:
  stderr:
    type: stderr
  stdout:
    type: stdout
  results:
    type: Directory
    outputBinding: { glob: "mapping" }   
  corrected:
    type: File
    outputBinding:
        glob: mapping/*_corrected.txt  


s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "n/a"
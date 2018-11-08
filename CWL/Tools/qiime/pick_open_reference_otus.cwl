#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

requirements:
  ResourceRequirement:
    coresMax: 1
    ramMin: 4096  # just a default, could be lowered

hints:
  DockerRequirement: 
    dockerPull: mgrast/qiime:1.0.20180919
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

arguments:
 - valueFrom: otus
   prefix: --output_dir
 - --force  

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
  
  
$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/docs/schema_org_rdfa.html

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "n/a"

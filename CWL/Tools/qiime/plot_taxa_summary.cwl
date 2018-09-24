#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
requirements:
  ResourceRequirement:
    coresMax: 1
    ramMin: 1024  # just a default, could be lowered
  InlineJavascriptRequirement: {}
  SchemaDefRequirement:
    types:
      - type: enum
        name: level-type
        symbols:
          - Domain
          - Phylum
          - Class
          - Order
          - Family
          - Genus
          - Species
     
hints:
  DockerRequirement: 
    dockerPull: mgrast/qiime:1.0.20180919
  SoftwareRequirement:
    packages:
      qiime:
        specs: [ "https://identifiers.org/rrid/RRID:SCR_008249" ]
        version: [ "1.9.1" ]


stderr: plot_taxa_summary.error
stdout: plot_taxa_summary.out

baseCommand: plot_taxa_summary.py
# -i /summarize_taxa_output/L2.txt,summarize_taxa_output/L3.txt,summarize_taxa_output/L4.txt,summarize_taxa_output/L5.txt,summarize_taxa_output/L6.txt,summarize_taxa_output/L7.txt
# -o /plot_taxa_summary_output/
# -l Phylum,Class,Order,Family,Genus,Species






inputs:
  taxa-counts-files:
   type: File[]
   doc: summarized taxa
   inputBinding:
     prefix: --counts_fname
     itemSeparator: ","
     valueFrom: |
          ${ 
              self.forEach( function(element) {
                                          var res = element.path.match(/_L(\d+)/);
                                          element.pos = res[1]
                                      } );
              return self.sort(function(a,b){ return a.pos - b.pos } )
          }
  labels:
    type: 
      - 'null'
      - level-type[]

    default: 'null'
    doc: |
      Comma-separated list of taxonomic levels (e.g.
      Phylum,Class,Order)  [default=none]
    inputBinding:
      prefix: --labels
      itemSeparator: ","

  output:
    type: string
    default: ./taxa-summary-plots
    inputBinding:
      prefix: --dir_path
      
arguments:
  - -s   
  - prefix: --chart_type 
    valueFrom: pie,area,bar  


outputs:
  stderr:
    type: stderr
  stdout:
    type: stdout  
  results:
    type: Directory?
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

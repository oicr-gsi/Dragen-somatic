version 1.0

struct InputGroup {
  File fastqR1
  File fastqR2
  String readGroup
}

struct GenomeResources {
    String dbSNP
    String referenceDirectory
    String dragenVersion
}

workflow dragenSomatic {
    input {
        Array[InputGroup]? normalInputs
        Array[InputGroup] tumorInputs
        String outputFileNamePrefix
        String reference
    }

    parameter_meta {
        normalInputs: "Input structure with normal fastq files and read group strings"
        tumorInputs: "Input structure with tumor fastq files and read group strings"
        outputFileNamePrefix: "Prefix for output files"
        reference: "The genome reference build. For example: hg19, hg38, mm10"
    }

    Map[String,GenomeResources] dragen_resources_by_genome = { 
    "hg38": {
      "dbSNP": "/.mounts/labs/gsiprojects/gsi/Dragen/reference/dbSNP.151/common_all_dbSNP151_hg38p7_sorted.vcf.gz",
      "referenceDirectory": "/.mounts/labs/gsiprojects/gsi/Dragen/reference/hg38fa.p12/",
      "dragenVersion": "4.2.4"
    }}

    String dragen_ref = dragen_resources_by_genome [ reference ].referenceDirectory
    String dragen_dbsnp = dragen_resources_by_genome [ reference ].dbSNP
    String dragen_version = dragen_resources_by_genome [ reference ].dragenVersion

    meta {
        author: "Peter Ruzanov"
        email: "pruzanov@oicr.on.ca"
        description: "A workflow for calling SNVs on tumor-only or tumor-normal inputs in somatic mode"
        dependencies: [
        {
          name: "gsi hg38 modules : hg38-dbsnp/151",
          url: "https://gitlab.oicr.on.ca/ResearchIT/modulator"
        },
        {
          name: "gsi modules : dragen-scripts/0.3",
          url: "https://gitlab.oicr.on.ca/ResearchIT/modulator"
        }]
        output_meta: {
          unfilteredVcf: {
            description: "SNV calls before applying any filters",
            vidarr_label: "unfilteredVcf"
          },
          unfilteredIdx: {
            description: "Index for SNV calls before applying any filters",
            vidarr_label: "unfilteredIdx"
          },
          filteredVcf: {
            description: "SNV calls with filter information attached",
            vidarr_label: "filteredVcf"
          },
          filteredIdx: {
            description: "Index for SNV calls with filter information attached",
            vidarr_label: "filteredIdx"
          },
          ploidyVcf: {
            description: "Ploidy vcf file",
            vidarr_label: "ploidyVcf"
          },
          ploidyIdx: {
            description: "Index for Ploidy vcf file",
            vidarr_label: "ploidyIdx"
          }
        }
    }

    # Compose input lines using read group data
    if (defined(normalInputs)) {
     scatter(n in select_first([normalInputs])) {
       call extractInfoLine as extractNormals {
         input:
         fastqInput = n
       }
     }

     call composeList as composeNormalList {
      input:
        inputLines = extractNormals.outputLine,
        outputFileName = "normal_inputs.csv"
     }
    } 

    # We expect tumor files always to be present
    scatter(t in tumorInputs) {
      call extractInfoLine as extractTumors {
        input:
        fastqInput = object{fastqR1: t.fastqR1, fastqR2: t.fastqR2, readGroup: t.readGroup}
      }
    }

    call composeList as composeTumorList {
      input:
        inputLines = extractTumors.outputLine,
        outputFileName = "tumor_inputs.csv"
    } 
    
    call runDragenSomatic {
      input:
        tumorFastqList = composeTumorList.inputList,
        normalFastqList =  composeNormalList.inputList,
        refDir = dragen_ref,
        dbSNP = dragen_dbsnp,
        outputFileNamePrefix = outputFileNamePrefix,
        dragenVersion = dragen_version
    } 

    output {
        File unfilteredVcf = runDragenSomatic.outputVcf
        File unfilteredIdx = runDragenSomatic.outputIdx
        File filteredVcf = runDragenSomatic.hardfilteredVcf
        File filteredIdx = runDragenSomatic.hardfilteredIdx
        File? ploidyVcf = runDragenSomatic.ploidyVcf
        File? ploidyIdx = runDragenSomatic.ploidyIdx
    }
}

# =====================================================================
# A scripted extraction of info from RG line to dragen-compliant string
# =====================================================================
task extractInfoLine {
   input {
       InputGroup fastqInput
       String parsingScript = "$DRAGEN_SCRIPTS_ROOT/bin/composeList.py"
       Int timeout = 4
       Int jobMemory = 4
       String modules = "dragen-scripts/0.3"
   }

   parameter_meta {
     fastqInput: "InputGroup struct entry with fastq files"
     parsingScript: "Script for parsing inputs into a line"
     timeout: "Timeout for the job"
     jobMemory: "Job allocated RAM"
     modules: "dependency modules"
   }

   command <<<
    python3 ~{parsingScript} -i ~{write_json(fastqInput)}
   >>>

   runtime {
     timeout: "~{timeout}"
     modules: "~{modules}"
     memory:  "~{jobMemory} GB"
   }

   output {
     String outputLine = read_string(stdout())
   }

   meta {
     output_meta: {
       outputLine: "Output line to use in a list of fastq files in dragen-compliant format"
     }
   }
}

# =====================================================================
#  Compose a dragen-compliant list of inputs to use with snv caller
# =====================================================================
task composeList {
   input  {
      Array[String] inputLines
      String listWritingScript = "$DRAGEN_SCRIPTS_ROOT/bin/writeFile.py"
      String outputFileName
      Int jobMemory = 4
      Int timeout = 4
      String modules = "dragen-scripts/0.3"
   }

   parameter_meta {
     inputLines: "Array of input lines to print"
     listWritingScript: "Script for writing out list of inputs"
     outputFileName: "Name of an output file, list of inputs"
     jobMemory: "Job allocated RAM"
     timeout: "Timeout for the job"
     modules: "dependency modules"
   }

   command<<<
   python3 ~{listWritingScript} -o ~{outputFileName} -l "~{sep=';' inputLines}"
   >>>
   

   runtime {
      timeout: "~{timeout}"
      modules: "~{modules}"
      memory:  "~{jobMemory} GB"
   }

   output {
     File inputList = "~{outputFileName}"
   }

   meta {
     output_meta: {
       inputList: "Output file to use with dragen SNV caller"
     }
   }
}
# ================================================================
# Main task for generating SNV calls in somatic mode (DRAGEN mode)
#
# we need CSV files with a header and data lines organized as:
#
# RGID Read Group
# RGSM Sample ID
# RGLB Library
# Lane Flow cell lane
# Read1File - Full path to a valid FASTQ input file
# Read2File - Full path to a valid FASTQ input file. Required for paired-end input. If not using paired-end input, leave empty.
# Each FASTQ file can only be referenced once in the CSV list.
# All values in the Read2File column must be reference valid files or must all be empty.
# ================================================================
task runDragenSomatic {
    input {
        File tumorFastqList
        File? normalFastqList
        String refDir
        String dragenVersion
        String? ponVcf
        String? additionalParameters
        String outputFileNamePrefix
        String dbSNP
        Int timeout = 96
    }

    parameter_meta {
        tumorFastqList: "List of tumor fastq files, required input"
        normalFastqList: "Optional list of normal fastq files for tumor-normal paired analysis"
        refDir: "The reference genome directoty"
        dragenVersion: "Expected version of dragen software on the DRAGEN node"
        additionalParameters: "Additional dragen parameters"
        dbSNP: "Path to the dbSNP reference file"
        ponVcf: "Optional path to panel of Normals (VCF) for filtering SNVs occuring in normal tissue"
        outputFileNamePrefix: "Output file name prefix"
        timeout: "Hours before task timeout"
    }
    
    String resultVcf = "~{outputFileNamePrefix}.vcf.gz"
    String hardfilteredVcfName = "~{outputFileNamePrefix}.hard-filtered.vcf.gz"
    String ploidyVcfName = "~{outputFileNamePrefix}.ploidy.vcf.gz"

    command <<<
      dragen -f -r ~{refDir} \
      --tumor-fastq-list ~{tumorFastqList} ~{"--fastq-list " + normalFastqList} \
      --enable-variant-caller true \
      --dbsnp ~{dbSNP} ~{"--panel-of-normals " + ponVcf} \
      --output-directory . \
      --output-file-prefix ~{outputFileNamePrefix} ~{additionalParameters}
    >>>
    runtime {
        backend: "DRAGEN"
        dragen_version: "~{dragenVersion}"
        timeout: "~{timeout}"
    }
    
    output {
        File outputVcf = "~{resultVcf}"
        File outputIdx = "~{resultVcf}.tbi"
        File hardfilteredVcf = "~{hardfilteredVcfName}"
        File hardfilteredIdx = "~{hardfilteredVcfName}.tbi"
        File? ploidyVcf = "~{ploidyVcfName}"
        File? ploidyIdx = "~{ploidyVcfName}.tbi"
    }

    meta {
        output_meta: {
            outputVcf: "output unfiltered vcf with SNV calls",
            outputIdx: "index of unfiltered vcf with SNV calls",
            hardfilteredVcf: "Hard-filtered vcf file with variants with filter info attached",
            hardfilteredIdx: "Index of Hard-filtered vcf file with variants with filter info attached",
            ploidyVcf: "Ploidy vcf",
            ploidyIdx: "Index of Ploidy vcf"
        }
    }

}


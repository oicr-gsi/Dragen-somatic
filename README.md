# dragenSomatic

A workflow for calling SNVs on tumor-only or tumor-normal inputs in somatic mode

## Overview

## Dependencies

* [gsi hg38 modules : hg38-dbsnp 151](https://gitlab.oicr.on.ca/ResearchIT/modulator)
* [gsi modules : dragen-scripts 0.3](https://gitlab.oicr.on.ca/ResearchIT/modulator)


## Usage

### Cromwell

```
java -jar cromwell.jar run dragenSomatic.wdl --inputs inputs.json
```

### Inputs

#### Required workflow parameters:
Parameter|Value|Description
---|---|---
`tumorInputs`|Array[InputGroup]|Input structure with tumor fastq files and read group strings
`outputFileNamePrefix`|String|Prefix for output files
`reference`|String|The genome reference build. For example: hg19, hg38, mm10


#### Optional workflow parameters:
Parameter|Value|Default|Description
---|---|---|---
`normalInputs`|Array[InputGroup]?|None|Input structure with normal fastq files and read group strings


#### Optional task parameters:
Parameter|Value|Default|Description
---|---|---|---
`extractNormals.parsingScript`|String|"$DRAGEN_SCRIPTS_ROOT/bin/composeList.py"|Script for parsing inputs into a line
`extractNormals.timeout`|Int|4|Timeout for the job
`extractNormals.jobMemory`|Int|4|Job allocated RAM
`extractNormals.modules`|String|"dragen-scripts/0.3"|dependency modules
`composeNormalList.listWritingScript`|String|"$DRAGEN_SCRIPTS_ROOT/bin/writeFile.py"|Script for writing out list of inputs
`composeNormalList.jobMemory`|Int|4|Job allocated RAM
`composeNormalList.timeout`|Int|4|Timeout for the job
`composeNormalList.modules`|String|"dragen-scripts/0.3"|dependency modules
`extractTumors.parsingScript`|String|"$DRAGEN_SCRIPTS_ROOT/bin/composeList.py"|Script for parsing inputs into a line
`extractTumors.timeout`|Int|4|Timeout for the job
`extractTumors.jobMemory`|Int|4|Job allocated RAM
`extractTumors.modules`|String|"dragen-scripts/0.3"|dependency modules
`composeTumorList.listWritingScript`|String|"$DRAGEN_SCRIPTS_ROOT/bin/writeFile.py"|Script for writing out list of inputs
`composeTumorList.jobMemory`|Int|4|Job allocated RAM
`composeTumorList.timeout`|Int|4|Timeout for the job
`composeTumorList.modules`|String|"dragen-scripts/0.3"|dependency modules
`runDragenSomatic.ponVcf`|String?|None|Optional path to panel of Normals (VCF) for filtering SNVs occuring in normal tissue
`runDragenSomatic.additionalParameters`|String?|None|Additional dragen parameters
`runDragenSomatic.timeout`|Int|96|Hours before task timeout


### Outputs

Output | Type | Description | Labels
---|---|---|---
`unfilteredVcf`|File|SNV calls before applying any filters|vidarr_label: unfilteredVcf
`unfilteredIdx`|File|Index for SNV calls before applying any filters|vidarr_label: unfilteredIdx
`filteredVcf`|File|SNV calls with filter information attached|vidarr_label: filteredVcf
`filteredIdx`|File|Index for SNV calls with filter information attached|vidarr_label: filteredIdx
`ploidyVcf`|File?|Ploidy vcf file|vidarr_label: ploidyVcf
`ploidyIdx`|File?|Index for Ploidy vcf file|vidarr_label: ploidyIdx


## Commands
This section lists commands run by dragenSomatic workflow
 
* dragenSomatic
 
dragenSomatic is a workflow which launches DRAGEN SNV calling pipeline. It creates
input lists based on information passed by the respective olive and then aligns
all reads using input fastq files, calling SNVs after that. It applies a number of
filters and adds annotations from dbSNP database, if available 
 
### Extracting information from RG line

```
     python3 ~{parsingScript} -i ~{write_json(fastqInput)}
```

### Composing a list of inputs 
 
```
    python3 ~{listWritingScript} -o ~{outputFileName} -l "~{sep=';' inputLines}"
```

### Running dragen SNV caller in somatic mode
 
```
       dragen -f -r ~{refDir} \
       --tumor-fastq-list ~{tumorFastqList} ~{"--fastq-list " + normalFastqList} \
       --enable-variant-caller true \
       --dbsnp ~{dbSNP} ~{"--panel-of-normals " + ponVcf} \
       --output-directory . \
       --output-file-prefix ~{outputFileNamePrefix} ~{additionalParameters}
```
## Support

For support, please file an issue on the [Github project](https://github.com/oicr-gsi) or send an email to gsi@oicr.on.ca .

_Generated with generate-markdown-readme (https://github.com/oicr-gsi/gsi-wdl-tools/)_

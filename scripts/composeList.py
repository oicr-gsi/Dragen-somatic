"""
   list composing function to use inside dragenSomatic, dragenGermline or dragenAlign workflows
"""

import json
import re
import argparse

parser = argparse.ArgumentParser(description='Parser for inputs to the script')
parser.add_argument('-i', '--input', help='input json string', required=True)
args = parser.parse_args()

'''Below are the lines to use in the wdl'''
with open(args.input, "r") as ji:
    inputData = json.load(ji)
ji.close()

try:
    myPattern = r'\S+?\:\S+'
    rgs = re.findall(myPattern, inputData['readGroup'])
    RGCN = "OICR"
    RGPL = "Illumina"
    for rgroup in rgs:
        if rgroup.startswith("ID:"):
            RGID = rgroup.split(":")[1]
            Lane = rgroup.split("_")[-2]
        if rgroup.startswith("PU:"):
            RGPU = rgroup.split(":")[1]
        if rgroup.startswith("PL:"):
            RGPL = rgroup.split(":")[1]
        if rgroup.startswith("SM:"):
            RGSM = rgroup.split(":")[1]
        if rgroup.startswith("CN:"):
            RGCN = rgroup.split(":")[1]
        if rgroup.startswith("LB:"):
            RGLB = rgroup.split(":")[1]
    fastqR1 = inputData['fastqR1']
    fastqR2 = inputData['fastqR2']
    myValues = [RGID, RGPU, RGPL, RGSM, RGLB, Lane, RGCN, fastqR1]
    if fastqR2 is not None:
        myValues.append(fastqR2)
    else:
        myValues.append("")
    myResult = ",".join(myValues)
    print(myResult)
except:
    print("Error parsing string")

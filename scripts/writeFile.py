"""
   Given an array of strings, write into a file formatted
   for dragenSomatic, dragenGermline or dragenAlign
"""
import argparse
import re

parser = argparse.ArgumentParser(description='Parser for inputs to the script')
parser.add_argument('-l', '--lanes', help='input strings', required=True)
parser.add_argument('-o', '--output', help='output file', required=True)
args = parser.parse_args()

inLines = re.split(";", args.lanes) if args.lanes else []
headerTitles = ["RGID", "RGSM", "RGLB", "Lane", "Read1File", "Read2File"]
linesToPrint = [",".join(headerTitles) + "\n"]
for inputString in inLines:
    inputString.rstrip()
    if not inputString.startswith("Error"):
        linesToPrint.append(inputString + "\n")
with open(args.output, "w") as tl:
    tl.writelines(linesToPrint)
tl.close()

import pandas as pd
import subprocess as sp
import glob

samples = pd.read_table(config["samples"], sep="\t").set_index('SampleID')

THREADS=config["threads"]
REFGENOME=config["refgenome"]
ONTMMIFILE=config["ontmmifile"]
WORKDIR=config["working_dir"]
FINALDIR=config["final_dir"]
INDIR=config["input_dir"]
PROJECT=config["project"]
BEDFILEDIR=config["bedfiledir"]

PREFIX=config["prefix_regex"]
lookupPrefix=config["prefix_lookup"]
prefix_column_format=config["sampleDB_prefix_format_columns"].split(",")
prefix_column_names=config["sampleDB_prefix_column_names"].split(",")


PREFIX_REGEX="/".join([PREFIX,PREFIX])
SAMPLE_WORKPATH="".join([WORKDIR, "/", PREFIX_REGEX]) # SAMPLE_WORKPATH should be used in all inputs up to moving the files to /n/alignments
LOG_REGEX=PREFIX

def apply_suffix(wildcards, ending, sampleID):
    # applies a suffix to the path of a sample folder and sample prefix, e.g. M1079-NP-{STRATEGY}-Project-OutsideID-pb/M1079-NP-{STRATEGY}-Project-OutsideID-pb.vcf.gz
    return ".".join([get_output_name(wildcards, sampleID), ending])

def get_prefix(wildcards, sampleID):
    if len(prefix_column_format) != len(prefix_column_names):
        raise ValueError("sampleDB_prefix_format_columns must contain the same number of comma separated values as sampleDB_prefix_column_names")
    sampleVals=[sampleID]
    sampleVals+=samples.loc[sampleID][prefix_column_names[1:]].values.tolist()
    column_pairs=dict(zip(prefix_column_format, sampleVals))
    return lookupPrefix.format(**column_pairs)

def get_output_name(wildcards, sampleID):
    #returns the path to a sample folder and sample prefix, e.g. M1079-NP-{STRATEGY}-Project-OutsideID-pb/M1079-NP-{STRATEGY}-ProjectOutsideID-pb
    prefix=get_prefix(wildcards, sampleID)
    return "/".join([prefix, prefix])

def get_output_dir(wildcards):
    # returns the working (Franklin) directory with specific folder, an absolute path. e.g. /data/alignments/M1079-NP-{STRATEGY}-Project-OutsideID-pb/
    sampleID=wildcards.SAMPLEID
    prefix=get_prefix(wildcards, sampleID)
    return "/".join(["{outdir}", prefix]).format(outdir=WORKDIR)

def get_final_dir(wildcards):
    # returns the destination (McClintock) directory with specific folder, a relative path
    sampleID=wildcards.SAMPLEID
    prefix=get_prefix(wildcards, sampleID)
    return "/".join(["{finaldir}", prefix]).format(finaldir=FINALDIR)

def get_targets_new(wildcards):
    f = open(config["targetfile"], "r")
    targets = f.read().split("\n")
    f.close()
    final_targets=[]
    if config["explicitLibraries"]:
        targetsamples=[x.split("-")[0] for x in targets]
    else:
        targetsamples=targets
    final_targets = []
    if config["qcCaller"] != "cramino" and config["qcCaller"] != "samtools":
        print("qcCaller value {} not recognized, using cramino".format(config["qcCaller"]))
        summarizer="cramino"
    else:
        summarizer=config["qcCaller"]
    endings=[]
    if config["outputs"]["alignBam"] or config["allTargets"]:
        endings+=["phased.bam", "phased.bam.bai"]
    if config["outputs"]["clair3"] or config["allTargets"]:
        endings+=["clair3.phased.vcf.gz", "clair3.notPhased.vcf.gz", "clair3.phased.vcf.gz.tbi", "clair3.notPhased.vcf.gz.tbi"]
    if config["outputs"]["sniffles"] or config["allTargets"]:
        endings+=["sv_sniffles.phased.vcf", "sv_sniffles.notPhased.vcf"]
    if config["outputs"]["svim"] or config["allTargets"]:
        endings+=["sv_svim.phased.vcf", "sv_svim.notPhased.vcf"]
    if config["outputs"]["cuteSV"] or config["allTargets"]:
        endings+=["sv_cutesv.phased.vcf", "sv_cutesv.notPhased.vcf"]
    if config["outputs"]["CNVcalls"] or config["allTargets"]:
        endings+=["called_cnv.vcf", "called_cnv.pdf", "called_cnv.detail_plot.pdf"]
    if config["outputs"]["VEP"] or config["allTargets"]:
        endings+=["clair3.phased.vep.111.vcf", "clair3.phased.vep.111.af_lt_1.csv"]
    if config["outputs"]["basicQC"] or config["allTargets"]:
        endings+=["phased.{}.stats".format(summarizer)]
    if config["outputs"]["phaseQC"] or config["allTargets"]:
        endings+=["clair3.phased.phasing_stats.tsv"]
    for ts in targetsamples:
        strategy=samples.loc[ts,"Strategy"]
        file_endings=endings
        if strategy == "RU":
            file_endings+=["phased.target.bam", "phased.target.bam.bai"]
            if config["outputs"]["basicQC"] or config["allTargets"]:
                file_endings+=["phased.target.{}.stats".format(summarizer)]
            if config["outputs"]["phaseQC"] or config["allTargets"]:
                file_endings+=["target.hp_dp.stats"]
        else:
            file_endings+=["hp_dp.stats"]
        all_targets = [apply_suffix(wildcards, x, ts) for x in file_endings]
        final_targets += all_targets
    return final_targets
        
        
def get_target_bams(wildcards):
    if config["explicitLibraries"]:
        f = open(config["targetfile"], "r")
        targets = f.read().split("\n")
        f.close()
        libraries=list(filter(lambda x: x.split("-")[0]==wildcards.SAMPLEID, targets))
        return ["{}/{}".format(INDIR,x) for x in libraries]
    else:
        strategy=wildcards.STRATEGY
        if strategy=="ALL":
            strategy="ONT"
        cmd="".join(["ls ", INDIR, "/", wildcards.SAMPLEID, "*", strategy, "*"])
        return sp.getoutput(cmd).split("\n")

def get_clair_model(wildcards):
    my_flowcell = samples.loc[wildcards.SAMPLEID,"Flowcell"]
    if my_flowcell=="R9":
        return '{}/clair3_models/r941_prom_sup_g5014'.format(config["clairmodelpath"])
    return '{}/rerio/clair3_models/r1041_e82_400bps_sup_v420'.format(config["clairmodelpath"])

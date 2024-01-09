# this rule should run vep and then make the output more readable.
rule filter_clair3_vcf:
    input:
        clair3_phased_vcf="".join([SAMPLE_WORKPATH, ".clair3.phased.vcf.gz"]),
        clair3_phased_vcf_index="".join([SAMPLE_WORKPATH, ".clair3.phased.vcf.gz.tbi"])
    output:
        clair3_phased_filtered_vcf=temp("".join([SAMPLE_WORKPATH, ".clair3.phased.filtered.vcf.gz"]))
    threads: THREADS
    log:
        o = "".join(["logs/",LOG_REGEX,"filter_clair3","-stdout.log"]),
        e = "".join(["logs/",LOG_REGEX,"filter_clair3","-stderr.log"])
    conda:
        config["conda_bcftools"]
    shell:
        """
        bcftools view --include 'FILTER="PASS"' -o {output.clair3_phased_filtered_vcf} {input.clair3_phased_vcf}
        """


rule run_vep:
    input:
        clair3_phased_filtered_vcf="".join([SAMPLE_WORKPATH, ".clair3.phased.filtered.vcf.gz"])
    output:
        vep_vcf=temp("".join([SAMPLE_WORKPATH, ".clair3.phased.vep.vcf"]))
    threads: THREADS
    log:
        o = "".join(["logs/",LOG_REGEX,"run_vep","-stdout.log"]),
        e = "".join(["logs/",LOG_REGEX,"run_vep","-stderr.log"])
    params:
        CADD="{}/CADDv1.6_hg38_whole_genome_SNVs.tsv.gz".format(config["vep_data_path"]),
        SPLICEAISNV="{}/spliceai_scores.raw.snv.hg38.vcf.gz".format(config["vep_data_path"]),
        SPLICEAIINDEL="{}/spliceai_scores.raw.indel.hg38.vcf.gz".format(config["vep_data_path"]),
        GNOMAD="{}/gnomad.genomes.v4.0.sites.hg38.vcf.gz".format(config["vep_data_path"]),
        CLINVAR="{}/clinvar.hg38.vcf.gz".format(config["vep_data_path"]),
        ALPHAMISSENSE="{}/AlphaMissense_hg38.tsv.gz".format(config["vep_data_path"]),
        cache_directory="{}/.vep".format(config["vep_caches_path"]),
        plugin_dir="{}/.vep/Plugins".format(config["vep_caches_path"])
    conda:
        config["conda_vep"]
    shell:
        """
        vep --cache --merged --offline --dir_cache {params.cache_directory} --force_overwrite --vcf --buffer_size 50000 \
        --pick_allele --use_given_ref --fork {THREADS} -i {input.clair3_phased_filtered_vcf} -o {output.vep_vcf} --canonical --symbol --numbers \
        --domains --pubmed --sift b --polyphen b --regulatory --total_length --numbers --af --max_af --af_1kg \
        --dir_plugins {params.plugin_dir} --plugin AlphaMissense,file={params.ALPHAMISSENSE} --plugin CADD,{params.CADD} \
        --plugin SpliceAI,snv={params.SPLICEAISNV},indel={params.SPLICEAIINDEL} --custom {params.GNOMAD},gnomADg,vcf,exact,0,AF \
        --custom {params.CLINVAR},ClinVar,vcf,exact,0,CLINSIG,CLNREVSTAT,CLNDN 2>> {log.e}
        """

# this rule  should filter the vep vcf
rule filter_vep:
    input:
        vep_vcf="".join([SAMPLE_WORKPATH, ".clair3.phased.vep.vcf"])
    output:
        vep_lt1_vcf=temp("".join([SAMPLE_WORKPATH, ".clair3.phased.vep.af_lt_1.csv"]))
    conda:
         config["conda_bcftools"]
    params:
        tmp_prefix="".join([SAMPLE_WORKPATH,".veptemp"])
    shell:
        """
        formatstring="%CHROM\t%POS\t%REF\t%ALT\t%QUAL\t[%GT\t%DP\t%AF\t%PS]\t%CSQ"
        bcftools +split-vep {input.vep_vcf} -f "$formatstring" -A "tab" > {params.tmp_prefix}.1.tsv

        collapsedoutput={params.tmp_prefix}.c.tsv
        notphasedoutput={params.tmp_prefix}.np.tsv

        awk -F "\t|," -v outputphased=$collapsedoutput -v outputnotphased=$notphasedoutput '{{if(NF>80){{print $0 \
        >> outputnotphased}}else{{print $0 >> outputphased}}}}' {params.tmp_prefix}.1.tsv

        awk -F "\t|," '{{print $1,$2,$3,$4,$6,$7,$8,$9,$11,$12,$14,$16,$18,$20,$22,$24,$26,$28,$30,$32,$34,$36,\
        $38,$40,$42,$44,$46,$48,$50,$52,$54,$56,$58,$60,$62,$64,$66,$68,$70,$72,$74,$76,$78,$80,$82,$84,$86,$88,$90,$92,$94,$96,$98,$100,$102,$104,\
        $106,$108,$110,$112,$114,$116,$118,$120,$122,$124,$126,$128,$130,$132,$134,$136,$138,$140,$142,$144; print $1,$2,$3,$5,$6,$7,$8,$10,$11,$13,\
        $15,$17,$19,$21,$23,$25,$27,$29,$31,$33,$35,$37,$39,$41,$43,$45,$47,$49,$51,$53,$55,$57,$59,$61,$63,$65,$67,$69,$71,$73,$75,$77,$79,$81,$83,\
        $85,$87,$89,$91,$93,$95,$97,$99,$101,$103,$105,$107,$109,$111,$113,$115,$117,$119,$121,$123,$125,$127,$129,$131,$133,$135,$137,$139,$141,$143\
        ,$145}}' $notphasedoutput > $collapsedoutput

        colnames="IGV TYPE DP_ALT DP_REF CHROM POS REF ALT QUAL GT DP AF PS Allele Consequence IMPACT SYMBOL Gene Feature_type Feature BIOTYPE EXON \
        INTRON HGVSc HGVSp cDNA_position CDS_position Protein_position Amino_acids Codons Existing_variation DISTANCE STRAND FLAGS SYMBOL_SOURCE HGNC_ID \
        CANONICAL REFSEQ_MATCH SOURCE REFSEQ_OFFSET GENE_PHENO SIFT PolyPhen DOMAINS AF_POP AFR_AF AMR_AF EAS_AF EUR_AF SAS_AF MAX_AF \
        MAX_AF_POPS CLIN_SIG SOMATIC PHENO PUBMED MOTIF_NAME MOTIF_POS HIGH_INF_POS MOTIF_SCORE_CHANGE TRANSCRIPTION_FACTORS CADD_PHRED \
        CADD_RAW SpliceAI_pred_DP_AG SpliceAI_pred_DP_AL SpliceAI_pred_DP_DG SpliceAI_pred_DP_DL SpliceAI_pred_DS_AG SpliceAI_pred_DS_AL \
        SpliceAI_pred_DS_DG SpliceAI_pred_DS_DL SpliceAI_pred_SYMBOL am_class am_pathogenicity gnomADg gnomADg_AF ClinVar ClinVar_CLINSIG \
        ClinVar_CLNREVSTAT ClinVar_CLNDN"

        echo $colnames | tr ' ' ',' > {output.vep_lt1_vcf}
        awk '{{type="SNV";if(length($3)!=length($4)){{type="INDEL"}};altdp=int($7*$8);refdp=$7-altdp;print $1":"$2,type,altdp,refdp,$0}}' \
        $collapsedoutput | tr ' ' ',' >> {output.vep_lt1_vcf}

        rm {params.tmp_prefix}*tsv
        """

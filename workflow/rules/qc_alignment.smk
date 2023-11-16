import glob

rule run_cramino:
    input:  
        bam = "".join([PREFIX_REGEX, ".phased.bam"]),
        bai = "".join([PREFIX_REGEX, ".phased.bam.bai"])
    output:
        stats = "".join([PREFIX_REGEX, ".phased.cramino.stats"])
    threads: 10
    conda: "../envs/alignment.yaml"
    shell:
        """
        cramino -t {threads} {input.bam} > {output.stats}
        """

rule run_whatshap:
    input:
        vcf = "".join([PREFIX_REGEX, ".clair3.phased.vcf.gz"]),
        tbi = "".join([PREFIX_REGEX, ".clair3.phased.vcf.gz.tbi"])
    output:
        stats = "".join([PREFIX_REGEX, ".clair3.phased.phasing_stats.tsv"])
    threads: 1
    conda: "../envs/alignment.yaml"
    shell:
        """
        whatshap stats --tsv={output.stats} {input.vcf}
        """

rule grep_all_cramino:
    input:
        stats = lambda wildcards: glob(("".join(["*-NP-WGS-{project}-*/*-NP-WGS-{project}-*.phased.cramino.stats"])).format(project=config["project"]))
    output:
        out_stats = "".join(["cramino.project.stats.tsv"])
    threads: 1
    shell:
        """
        echo -e "Filename\tYield\tCoverage\tYieldOver25kb\tN50\tIdentity" > {output.out_stats}
        ALLFILES=( {input.stats} )
        for FILE in ${ALLFILES[@]}
        do
            GB=$(sed '4q;d' $FILE | cut -f 2)
            READS=$(sed '2q;d' $FILE | cut -f 2)
            COV=$(sed '5q;d' $FILE | cut -f 2)
            GB25kb=$(sed '6q;d' $FILE | cut -f 2)
            N50=$(sed '7q;d' $FILE | cut -f 2)
            IDENTITY=$(sed '12q;d' $FILE | cut -f 2)
            echo -e "$FILE\t$GB\t$COV\t$GB25kb\t$N50\t$IDENTITY" >> {output.out_stats}
        done
        """

rule grep_phase_stats:
    input:
        stats = lambda wildcards: glob(("".join(["*-NP-WGS-{project}-*/*-NP-WGS-{project}-*.clair3.phased.phasing_stats.tsv"])).format(project=config["project"]))
    output:
        out_stats = "".join(["phasing.project.stats.tsv"])
    threads: 1
    shell:
        """
        ALLFILES=( {input.stats} )
        FILE0 = ${ALLFILES[0]}
        head -n1 $FILE1 > {output.out_stats}
        for FILE in ${ALLFILES[@]}
        do
            grep "ALL" $FILE >> {output.out.stats}
        done
        """
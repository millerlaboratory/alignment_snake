rule move_anything:
    input: "".join([WORKDIR,"/",PREFIX_REGEX,"{whatever}"])
    output: protected("".join([FINALDIR,"/",PREFIX_REGEX,"{whatever}"]))
    threads: 1
    shell:
        """
        cp {input} {output}
        """
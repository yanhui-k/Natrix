#def get_fastq(wildcards, read_pair='fq1'):
#    return units.loc[(wildcards.sample, wildcards.unit), [read_pair]].dropna()
def get_fastq(wildcards):
    if not is_single_end(wildcards.sample, wildcards.unit):
        return expand('demultiplexed/{sample}_{unit}_{group}.fastq', group=[1,2], **wildcards)
    return 'demultiplexed/{sample}_{unit}_1.fastq'.format(**wildcards)

rule unzip:
    input:
         'demultiplexed/{sample}_{unit}_R{read}.fastq.gz'
    output:
        'demultiplexed/{sample}_{unit}_{read}.fastq'
    shell: 'gunzip -c {input} > {output}'

# I dont even think that the define primer script is really neccessary, afaik it was just some spaghetti from the old pipeline
# if it is neccessary, I have to adjust it that is also works for single end data
#rule define_primer:
#    input:
#        primer_table = config['general']['filename'] + '.csv'
#    output:
#        'p_table_with_primer.csv'
#    script:
#        '../scripts/define_primer.R'
rule prinseq:
    input:
        sample=get_fastq
    output:
        expand('results/assembly/{{sample}}_{{unit}}/{{sample}}_{{unit}}_{read}.fastq', read=reads)
    params:
        config['qc']['mq']
    run:
        if(len(input)) == 2:
            output_edit = str(output[0])[:-8]
            output_bad = str(output[0])[:-8] + '_bad'
            shell('bin/prinseq-lite/prinseq-lite.pl -verbose -fastq {input[0]} -fastq2 {input[1]} -ns_max_n 0 -min_qual_mean {params} -out_good {output_edit} -out_bad {output_bad} 2>&1')
        else:
            output_edit = str(output)[:-6]
            output_bad = str(output)[:-6] + '_bad'
            shell('bin/prinseq-lite/prinseq-lite.pl -verbose -fastq {input[0]} -ns_max_n 0 -min_qual_mean {params} -out_good {output_edit} -out_bad {output_bad} 2>&1')

rule assembly:
    input:
        expand('results/assembly/{{sample}}_{{unit}}/{{sample}}_{{unit}}_{read}.fastq', read=reads),
        primer_t = config['general']['filename'] + '.csv'
    output:
        'results/assembly/{sample}_{unit}/{sample}_{unit}_assembled.fastq'
    params:
        paired_end = config['merge']['paired_End'],
        threshold = config["qc"]["threshold"],
        minoverlap = config["qc"]["minoverlap"],
        minlen = config["qc"]["minlen"],
        maxlen = config["qc"]["maxlen"],
        minqual = config["qc"]["minqual"],
        prim_rm = config["qc"]["all_primer"]
    conda:
        '../envs/assembly.yaml'
    log:
        'logs/{sample}_{unit}/read_assembly.log'
    script:
        '../scripts/assembly.py'

rule copy_to_fasta:
    input:
        'results/assembly/{sample}_{unit}/{sample}_{unit}_assembled.fastq'
    output:
        'results/assembly/{sample}_{unit}/{sample}_{unit}.fasta'
    shell:
        'cat {input} | paste - - - - | cut -f 1,2 | sed "s/^@/>/g" | tr "\t" "\n" > {output}'
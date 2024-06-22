# Multi-omics


## 2023-06-15

N integration (Multi-omics)


## DIABLO
Integrating data sets of (called blocks) measured on the same samples

- X should be named list of data sets, so each $X_i$ is of $P \times N$, $P$ is fixed, $N$ is different in each block. And, $X =$ [ $X_1 , X_2, ... X_n$]
- Y , factor or class vector for discrete outcome



## 2023-06-12
Central Dogma:
DNA - RNA - Protein -> metabolites

ACGT
TGCA
A-T, G_C

A/A, A/T, T/T

Rna

Counting molecules

- mRNA -> read by DNA primary
- regulatory RNA (control process)
    + methylation
    + miRNA (10-19 nt) 
    + lncRNA (100s) very few amount, they flow around --> Danton knows more
Data Integration

Matrices of many variables

N samples , P variables. So integration is just rbind / cbind them?

P integration (Columns are constant, meta0analysis)  

N integration (Row are constant, multimodal, multi-omics)

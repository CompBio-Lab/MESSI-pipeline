# Results

This is a directory to store output from methods and reports from html. Also, for more detailed monitoring of you could look into the following files:


<details>
    <summary> View File Structure and Description </summary>
    
    ├── nxf_logs (nextflow's built-in log, more of Java style)
    │   ├── 2023-06
    │   │   └── ...
    │   └── 2023-07
    │       ├── ...
    ├── pbs_output (stdout of the batch job on PBS)
    │   ├── 2023-06
    │   │   ├── ...
    │   └── 2023-07
    │       ├── ...
    ├── README.md
    └── reports (execution report with memory, resource usage details)
        ├── 2023-06
        │   ├── ...
        └── 2023-07
            ├── ...

</details>

Moreover, logs will be deleted by schedule (To be determined).



~~Note: this is ignored by `.gitignore`, and only this file and a sample report `*.html` would stay here.~~


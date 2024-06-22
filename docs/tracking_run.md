
|     Job ID    |     Nodes |  Num_cpus (core) | Time     | CPU % usage (More better) | Real Time  | Timestamp |
|     :-:       |     :-:   |       :-:        |   :-:      |          :-:              |     :-:     | :-: |
|  5402572      |     1     |         32       |    5m 51s  |   3169.3               |     6m 57s        | ...|
|   5402583     |     2     |         32       |   5m 58s       |                        |            |  2023-09-18_17-59-02| 
| 5402584       |    4      |         32       |   6m 7s     |           | No | 2023-09-18_17-59-10|
| 5402585   |         8     |         32       |   6m 12s     |           | No| 2023-09-18_17-59-17 |
| 5402629   |     1       |     40    |  6m 14s     |  3959.5       |    5m 59s       |       .... |

---



- So increasing nodes this would make the following:
  + tsk = nodes * ncpus = 8 * 32 = 256
  + Mem = nodes * memory_each = 8 * 16GB = 128GB
- Tsk equivalent to ncpus (core)
- Nodes equivalent to number of computer, dont seem to affect here
- Increasing node not help too much
  + Might take more time ?
- 32 Cpus seems to work fine, 64 takes time in Queue
- 48 Cpus still queue

>  WARN: cpus and memory directives are ignored when clusterOptions contains -l option

> tip: clusterOptions = { "-l select=1:ncpus=${task.cpus}:mem=${task.memory.toMega()}mb:..." } 

Change this above in `pbs_remote.config`

---

Node specifications:

The link could be found [here](https://confluence.it.ubc.ca/display/UARC/About+Sockeye) for resources 
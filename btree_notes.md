# sqlite

[ref](https://sqlite.org/fileformat2.html)

leaf page contains keys

- interior page contains k keys, with k+1 "pointers (uint page number)"  
- structure: 
  - 100b header, if page 1
  - 8 or 12 b b-tree page header
  - cell pointer array
  - unallocated space
  - cell content
  - reserved region

# postgres

[ref](https://www.postgresql.org/docs/12/storage-page-layout.html)

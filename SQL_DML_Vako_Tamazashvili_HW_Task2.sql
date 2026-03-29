-- Task 2  delete and truncate

-- i tracked total_bytes to measure disk space consumption as it represents the total size of the table.

-- after the first operations Table occupies 602415104 bytes.

-- after delete - Table size remains almost the same, even though 1/3 of rows are removed - 602611712 Bytes, it took 16 seconds

-- "public.table_to_delete": found 18 removable, 6666667 nonremovable row versions in 73536 pages, after vacuum full
-- table size siginificantly recreases because storage is phyisically reclaimed. -- > 401580032 Bytes

-- Truncate took 1.08 seconds, and the table size is reduced to 8192 Bytes, near zero.

/* Delete vs truncate. Delete is slow because it removes row one by one, Truncate does it all at once so its much faster.
 Delete does not free disk space immediately, truncate frees it instantly.
 Delete is fully transactional (row-level operation), Truncate is minimally logged and behaves like a DDL operation
 Delete can be rolled back, Truncate can be rolled back but not in all databases, it can be rolled back in postgresql.
 
 */

/* Explanations
 Delete does not physically remove rows from the disk but marks rows 'dead tuples' and they still occupy space until its
 cleaned by Vacuum
 Vacuum rewrites entire table into a new file and it removes dead tuples which results in freeing up the disk space.
 Truncate does not scan any rows whatsoever, it instantly removes all rows which results in much faster performance.
 To summarize it, delete is slower and requires vacuum, it is suitable for selective row removal. Truncate is very fast
 and frees up space immediately, suitable for removing all rows.
 Vacuum full is expensive operation but neccessary to recalim the disk space.
 */

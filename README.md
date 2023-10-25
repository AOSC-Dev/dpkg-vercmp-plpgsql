# PL/pgSQL impelemtation of version comparison routines in dpkg

This is a PL/pgSQL implementation of version comparison routines which present in dpkg.

This implementation is based on https://git.dpkg.org/git/dpkg/dpkg.git/tree/lib/dpkg/version.c?id=dfa09efcbaca4bffd41341ced89a827494843abc .

Definition
----------

The definition of `dpkg_version_compare` is as follows:

```sql
CREATE OR REPLACE FUNCTION dpkg_version_compare(
        a varchar(120),
        b varchar(120)
    )
    PARALLEL safe
    RETURNS integer
    LANGUAGE plpgsql
```

Usage
--------

Run the `dpkg_vercmp.sql` file, which creates three functions in the default database schema:

```
$ psql -f /path/to/dpkg_vercmp.sql
CREATE FUNCTION
CREATE FUNCTION
CREATE FUNCTION
```

Either directly call `dpkg_version_compare(varchar(120), varchar(120))` in your PL/pgSQL function, or call this function using `SELECT`.

### PL/SQL usage

Here's an example of calling `dpkg_version_compare` in PL/pgSQL code:

```sql
CREATE OR REPLACE FUNCTION myfunc() AS $$
DECLARE
    result integer DEFAULT 0;
BEGIN
    result := dpkg_version_compare('1.2.3', '1.2.3-1');
    IF result > 0 THEN
        RAISE NOTICE '1.2.3 is greater than 1.2.3-1! How strange is that!';
    ELSIF result = 0 THEN
        RAISE NOTICE '1.2.3 is the same as 1.2.3-1! How strange is that!';
    ELSE
        RAISE NOTICE '1.2.3 is smaller than 1.2.3-1.';
    END IF;
END;
$$;
```

The result should be:

```
1.2.3 is smaller than 1.2.3-1.
```

### Using `SELECT`

```sql
SELECT dpkg_version_compare('1.2.3', '1.2.4');
```

The result should be:

```
=# SELECT dpkg_version_compare('1.2.3', '1.2.4');
 dpkg_version_compare
----------------------
                   -1
(1 row)
```

Return Values
-------------

The return value is an integer.

Possible return values are:

- `> 0` if a is greater than b.
- `= 0` if a equals b.
- `< 0` if a is smaller than b.

Performance
-----------

1,000,000 queries of the same value took around 8,100 ms, with my Intel Core i7 12700 machine, which runs at 4.8GHz.

The code itself does not involve any database queries.

Use the following code if you want to benchmark yourself:

```sql
do $$
declare
	rounds integer := 1000000;
	start_ms1 timestamptz;
	end_ms1 timestamptz;
	interval1 double precision;
begin
	start_ms1 = clock_timestamp();
	raise notice 'Benchmark of 1,000,000 queries of dpkg_version_compare started at %', start_ms1;
	for i in 1..rounds loop
		PERFORM dpkg_version_compare('1:1.2.3', '1:1.3.0');
	end loop;
	end_ms1 = clock_timestamp();
	raise notice 'Benchmark of 1,000,000 queries of dpkg_version_compare ended at %', end_ms1;
	interval1 := 1000 * ( extract(epoch from end_ms1) - extract(epoch from start_ms1) );
	raise notice 'Benchmark took % ms.', interval1;
end;
$$;
```

LICENSE
---------

This piece of code is licensed under GNU General Public License Version 2 (GPLv2).

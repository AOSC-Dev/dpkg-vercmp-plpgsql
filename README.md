# PL/pgSQL impelemtation of version comparison routines in dpkg

This is a PL/pgSQL implementation of version comparison routines which present in dpkg.

This implementation is based on https://git.dpkg.org/git/dpkg/dpkg.git/tree/lib/dpkg/version.c?id=dfa09efcbaca4bffd41341ced89a827494843abc .

Usage
--------

Run the `dpkg_vercmp.sql` file, which creates three functions in the default database schema.

Either directly call `dpkg_version_compare(varchar(120), varchar(120))` in your PL/pgSQL function, or call this function with `SELECT`.

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

### Directly call with `SELECT`

```sql
SELECT dpkg_version_compare('1.2.3', '1.2.4');
```

The result would be:
- `1` if a is greater than b.
- `0` if a equals b.
- `-1` if a is smaller than b.

LICENSE
---------

This piece of code is licensed under GNU General Public License Version 2 (GPLv2).

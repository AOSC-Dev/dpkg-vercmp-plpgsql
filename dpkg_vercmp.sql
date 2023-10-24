/*
 * Cyan's PL/pgSQL implementation of the version comparision routines from libdpkg
 * As PL/pgSQL.
 * Copyright (C) 2023 Cyan.
 * Licensed under GNU GPLv2.
 */

/*
 * https://git.dpkg.org/git/dpkg/dpkg.git/tree/lib/dpkg/version.c?id=dfa09efcbaca4bffd41341ced89a827494843abc#n67
 * PL/pgSQL implementation of order() in libdpkg.
 * Give a weight to the character to order in the version comparison.
 * Param c: an ASCII character.
 * 
 * NOTE: You can use chr() to acquire it.
 */
CREATE OR REPLACE FUNCTION dpkg_ver_order(c character)
 RETURNS integer
 LANGUAGE plpgsql
 PARALLEL safe
AS $$
BEGIN
	CASE
	when c between '0' and '9' then
		return 0;
	when c between 'a' and 'z' then
		return ascii(c);
	when c between 'A' and 'Z' then 
		return ascii(c);
	when c = '~' then
		return (ascii(c) + 256);
	else
		return 0;
	end case;
end;
$$;

/*
 * https://git.dpkg.org/git/dpkg/dpkg.git/tree/lib/dpkg/version.c?id=dfa09efcbaca4bffd41341ced89a827494843abc#n82
 * PL/PGSQL implementation of verrevcmp(char *, char *).
 * See dpkg-version(5) for details.
 * 
 * Returns int > 0 if a is greater than b.
 * Returns int = 0 if a and b are equal.
 * Returns int < 0 if a is smaller than b.
 */
CREATE OR REPLACE FUNCTION dpkg_verrevcmp(a varchar(120) default '', b varchar(120) default '')
 RETURNS integer
 parallel safe
 language plpgsql
as $$
declare
	ch_a char;		-- register to hold a char in string a
	ch_b char;		-- register to hold a char in string b
	chseq_a varchar(120);	-- Copy of a
	chseq_b varchar(120);	-- Copy of b
	len_a integer;		-- Length of a (to save a few char_length() calls.)
	len_b integer;		-- Length of b
	ord_a integer;		-- order of the ch_a
	ord_b integer;		-- order of the ch_b
	first_diff integer;	-- first difference
begin
	/*
	 * Make sure we do not have empty string in both or either of a and b.
	 */
	len_a := char_length(a);
	len_b := char_length(b);
	if len_a = 0 and len_b = 0 then
		return 0;
	elsif len_a = 0 then
		return 0 - ascii(b);	-- to be consistent with libdpkg.
	elsif len_b = 0 then
		return ascii(a);	-- to be consistent with libdpkg.
	end if;
	/*
	 * Now that's empty string's taken care of.
	 */
	chseq_a := a;
	chseq_b := b;
	ch_a = left(chseq_a, 1);
	ch_b = left(chseq_b, 1);
	while ch_a != '' or ch_b != '' loop
		first_diff := 0;
		/*
		 * https://git.dpkg.org/git/dpkg/dpkg.git/tree/lib/dpkg/version.c?id=dfa09efcbaca4bffd41341ced89a827494843abc#n92
		 * First loop to deal with alphabets and symbols.
		 * (Hope we do not have control characters and '\0' in the version strings.)
		 */
		while (ch_a != '' and ch_a not between '0' and '9') or (ch_b != '' and ch_b not between '0' and '9') loop
			/*
			 * If b is shorter than a, left('', 1) always returns an empty string.
			 * Calling dpkg_ver_order('') yields 0, which is expected.
			*/
			ch_a := left(chseq_a, 1);
			ch_b := left(chseq_b, 1);
			ord_a := dpkg_ver_order(ch_a);
			ord_b := dpkg_ver_order(ch_b);
			if ord_a != ord_b then
				return ord_a - ord_b;
			end if;
			/*
			 * https://git.dpkg.org/git/dpkg/dpkg.git/tree/lib/dpkg/version.c?id=dfa09efcbaca4bffd41341ced89a827494843abc#n99 :
			 * a++;
			 * b++;
			 * What we are going to do, is to pop the left most character in the both of the strings
			 * into the ch_a and ch_b register.
			 */
			chseq_a = substr(chseq_a, 2);
			chseq_b = substr(chseq_b, 2);
			ch_a = left(chseq_a, 1);
			ch_b = left(chseq_b, 1);
			-- ^ Turned out it worked great :D
		end loop;
		/*
		 * https://git.dpkg.org/git/dpkg/dpkg.git/tree/lib/dpkg/version.c?id=dfa09efcbaca4bffd41341ced89a827494843abc#n102
		 * Two loops to deal with '0' characters.
		 */
		while ch_a = '0' loop
			chseq_a = substr(chseq_a, 2);
			ch_a = left(chseq_a, 1);
		end loop;
		while ch_b = '0' loop
			chseq_b = substr(chseq_b, 2);
			ch_b = left(chseq_b, 1);
		end loop;
		/*
		 * https://git.dpkg.org/git/dpkg/dpkg.git/tree/lib/dpkg/version.c?id=dfa09efcbaca4bffd41341ced89a827494843abc#n106
		 * Deal with difference between digits currently in ch_a and ch_b.
		 */
		while (ch_a between '0' and '9') and (ch_b between '0' and '9') loop
			if first_diff = 0 then
				first_diff = ascii(ch_a) - ascii(ch_b);
			end if;
			chseq_a = substr(chseq_a, 2);
			chseq_b = substr(chseq_b, 2);
			ch_a = left(chseq_a, 1);
			ch_b = left(chseq_b, 1);
		end loop;
		if (ch_a between '0' and '9') then
			return 1;
		end if;
		if (ch_b between '0' and '9') then
			return -1;
		end if;
		if first_diff != 0 then
			return first_diff;
		end if;
	end loop;
	return 0;
end;
$$;

/*
 * https://git.dpkg.org/git/dpkg/dpkg.git/tree/lib/dpkg/version.c?id=dfa09efcbaca4bffd41341ced89a827494843abc#n140
 * PL/pgSQL implementation of dpkg_version_compare().
 * Since we do not have structs defined, we have to splict the version string into
 * epoch, main version and debian revision.
 */
CREATE OR REPLACE FUNCTION dpkg_version_compare(verstr_a varchar(120), verstr_b varchar(120))
 RETURNS integer
 PARALLEL safe
 LANGUAGE plpgsql
AS $$
DECLARE
	rc integer = 0;
	colon_a integer = 0;	-- Position of the colon in the version string.
	colon_b integer = 0;
	hypen_a integer = 0;	-- POSITION OF the hypen IN the VERSION string.
	hypen_b integer = 0;
	epoch_a integer = 0;
	epoch_b integer = 0;
	epoch_a_str varchar(120) DEFAULT '';
	epoch_b_str varchar(120) DEFAULT '';
	ver_a varchar(120) DEFAULT '';
	ver_b varchar(120) DEFAULT '';
	/*
	 * The reason why we have ' ' as default string is:
	 * - Spaces can not be present in the version string.
	 * - if we feed a '' to dpkg_verrevcomp(), the value is not actually NULL.
	 */
	rel_a varchar(120) DEFAULT ' ';
	rel_b varchar(120) DEFAULT ' ';
BEGIN
	IF strpos(verstr_a, ' ') > 0 OR strpos(verstr_b, ' ') > 0 THEN
		RAISE 'Spaces are not allowed in version strings: either in "%" or "%".', verstr_a, verstr_b;
	END IF;
	/*
	 * epoch - try to find the colon, and check if epoch value is empty.
	 */
	colon_a := strpos(verstr_a, ':');
	colon_b := strpos(verstr_b, ':');
	IF colon_a = 1 OR colon_b = 1 THEN
		RAISE 'Epoch value is empty in version string "%" or "%".', verstr_a, verstr_b;
	END IF;
	/*
	 * Tries to convert the resulting epoch into an integer.
	 */
	BEGIN
		IF colon_a > 0 THEN
			epoch_a_str := substr(verstr_a, 1, (colon_a - 1));
			epoch_a := int4(epoch_a_str);
		END IF;
		IF colon_b > 0 THEN
			epoch_b_str := substr(verstr_b, 1, (colon_b - 1));
			epoch_b := int4(epoch_b_str);
		END IF;
		IF epoch_a < 0 OR epoch_b < 0 THEN 
			RAISE 'Epoch value is negavive, which is not allowed, either in "%" or "%".', epoch_a_str, epoch_b_str;
		END IF;
	EXCEPTION
		WHEN invalid_text_representation THEN
			RAISE 'Invalid epoch value encountered, either in "%" or "%".', epoch_a_str, epoch_b_str;
		WHEN numeric_value_out_of_range THEN
			RAISE 'Epoch value is either too large or too small, either in "%" or "%".', epoch_a_str, epoch_b_str;
	END;
	/*
	 * Done dealing with epoches.
	 */
	hypen_a := strpos(verstr_a, '-');
	hypen_b := strpos(verstr_b, '-');
	IF hypen_a = char_length(verstr_a) OR hypen_b = char_length(verstr_b) THEN
		RAISE 'Revision value is empty in version string "%" or "%".', verstr_a, verstr_b;
	END IF;
	/*
	 * Get main version and rel.
	 */
	IF hypen_a > 0 THEN
		rel_a := substr(verstr_a, hypen_a + 1);
		ver_a := substr(verstr_a, colon_a + 1, hypen_a - colon_a - 1);
	ELSIF hypen_a = 0 THEN
		ver_a := substr(verstr_a, colon_a + 1);
	END IF;
	IF hypen_b > 0 THEN
		rel_b := substr(verstr_b, hypen_b + 1);
		ver_b := substr(verstr_b, colon_b + 1, hypen_b - colon_b - 1);
	ELSIF hypen_b = 0 THEN
		ver_b := substr(verstr_b, colon_b + 1);
	END IF;
	IF ver_a = '' OR ver_b = '' THEN
		RAISE 'Main version string is empty, either in "%" or "%"', verstr_a, verstr_b;
	END IF;
	/*
	 * https://git.dpkg.org/git/dpkg/dpkg.git/tree/lib/dpkg/version.c?id=dfa09efcbaca4bffd41341ced89a827494843abc#n143
	 * Main comparison code.
	 */
	IF epoch_a > epoch_b THEN
		RETURN 1;
	ELSIF epoch_a < epoch_b THEN
		RETURN -1;
	END IF;
	rc := dpkg_verrevcmp(ver_a, ver_b);
	IF rc != 0 THEN
		RETURN rc;
	ELSE
		rc := dpkg_verrevcmp(rel_a, rel_b);
		RETURN rc;
	END IF;
END;
$$;

-- 3.1
--========================================================= students
create or replace function insert_students(count integer, date_entry date) returns void
    volatile
    language plpgsql
as
$$
BEGIN
    INSERT INTO "Student" (
       select (names.id + last_amka.amkas::int) amka,
              names.name as name,
              father_names.name as father_name,
              adapt_surname(surnames.surname, names.sex) as surname,
              concat('s', create_am(extract(year from date_entry)::int, names.id + last_amka.amkas::int), '@isc.tuc.gr')::character(30) as email,
              create_am(extract(year from date_entry)::int, names.id + last_am.ams::int)::character(10) as am,
              date_entry as entry_date
       from random_names(count) as names,
            (select row_number() over ()::int id, sn.surname as surname from (select * from random_surnames(count) s) sn) surnames,
            (select row_number() over ()::int id, fn.name as name, sex from (select n.name as name, sex from "Name" n where sex = 'M' order by random() limit 30) fn) father_names,
            (select COUNT(s.am) as ams from "Student" s where s.am like concat(extract(year from date_entry), '%')) last_am,
            (select COUNT(*) as amkas from "Student") last_amka
       where names.id = father_names.id and surnames.id = names.id
    );
END;
$$;
alter function insert_students(int, date) owner to postgres;

--========================================================= professors
create or replace function insert_professors(count integer) returns void
    volatile
    language plpgsql
as
$$
BEGIN
    INSERT INTO "Professor" (
         select (names.id + last_amka.amkas::int) amka,
            names.name as name,
            father_names.name as father_name,
            adapt_surname(surnames.surname, names.sex) as surname,
            concat('p', create_am(extract(year from CURRENT_DATE)::int, names.id + last_amka.amkas::int + 30), '@isc.tuc.gr')::character(30) as email,
            floor(random() * (last_lab.labs - 1) + 1)::int as labJoins,
            random_ranks.r as rank
        from random_names(count) as names,
            (select row_number() over ()::int id, sn.surname as surname from (select * from random_surnames(count) s) sn) surnames,
            (select row_number() over ()::int id, fn.name as name, sex from (select n.name as name, sex from "Name" n where sex = 'M' order by random() limit count) fn) father_names,
            (select COUNT(*) + 20000-1 as amkas from "Professor") last_amka,
            (select COUNT(lab_code) as labs from "Lab") last_lab,
            (select row_number() over ()::int id, rand_ranks.r as r
                from (select floor(ids * 4 + 1) as id from generate_series(0, 1, 1.0/count) ids order by random()) rand_id,
                    (select r, row_number() OVER ()::integer as id from unnest(enum_range(NULL::rank_type)) r) rand_ranks
                where rand_id.id = rand_ranks.id) random_ranks
        where names.id = father_names.id and surnames.id = names.id and random_ranks.id = names.id
    );
END;
$$;
alter function insert_professors(integer) owner to postgres;


--========================================================= lab staff
create or replace function insert_labstaff(count integer) returns void
    volatile
    language plpgsql
as
$$
BEGIN
    INSERT INTO "LabStaff" (
        select names.id + last_amka.amkas::int amka,
            names.name as name,
            father_names.name as father_name,
            adapt_surname(surnames.surname, names.sex) as surname,
            concat('l', create_am(extract(year from CURRENT_DATE)::int, names.id + last_amka.amkas::int), '@isc.tuc.gr')::character(30) as email,
            floor(random() * (last_lab.labs - 1) + 1) as labworks,
            random_level.l as level
        from random_names(count) as names,
            (select row_number() over ()::int id, sn.surname as surname from (select * from random_surnames(count) s) sn) surnames,
            (select row_number() over ()::int id, fn.name as name, sex from (select n.name as name, sex from "Name" n where sex = 'M' order by random() limit count) fn) father_names,
            (select COUNT(*) + 29999 as amkas from "LabStaff") last_amka,
            (select COUNT(lab_code) as labs from "Lab") last_lab,
            (select row_number() over ()::int id, rand_levels.l as l
                from (select floor(ids * 4 + 1) as id from generate_series(0, 1, 1.0/count) ids order by random()) rand_id,
                    (select l, row_number() OVER ()::integer as id from unnest(enum_range(NULL::level_type)) l) rand_levels
                where rand_id.id = rand_levels.id) random_level
        where names.id = father_names.id and surnames.id = names.id and random_level.id = names.id
    );
END;
$$;
alter function insert_labstaff(integer) owner to postgres;

